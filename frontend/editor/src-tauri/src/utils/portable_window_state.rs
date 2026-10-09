use serde::{Deserialize, Serialize};
use std::{
    collections::HashMap,
    env,
    fs,
    path::PathBuf,
    sync::{Arc, Mutex},
};
use tauri::{
    AppHandle, Manager, PhysicalPosition, PhysicalSize, Runtime, WebviewWindow, Window, WindowEvent,
};

const WINDOW_STATE_FILE: &str = ".window-state.json";

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
struct WindowState {
    width: u32,
    height: u32,
    x: i32,
    y: i32,
    prev_x: i32,
    prev_y: i32,
    maximized: bool,
    visible: bool,
    decorated: bool,
    fullscreen: bool,
}

impl Default for WindowState {
    fn default() -> Self {
        Self {
            width: 0,
            height: 0,
            x: 0,
            y: 0,
            prev_x: 0,
            prev_y: 0,
            maximized: false,
            visible: true,
            decorated: true,
            fullscreen: false,
        }
    }
}

#[derive(Clone)]
struct PortableWindowStateCache(Arc<Mutex<HashMap<String, WindowState>>>);

fn portable_state_path() -> Result<PathBuf, String> {
    let root = env::var_os("PDF_TUNNER_PORTABLE_ROOT")
        .map(PathBuf::from)
        .ok_or_else(|| "PDF_TUNNER_PORTABLE_ROOT is not set".to_string())?;
    Ok(root
        .join("data")
        .join("tauri")
        .join("window-state")
        .join(WINDOW_STATE_FILE))
}

fn load_state() -> Result<HashMap<String, WindowState>, String> {
    let path = portable_state_path()?;
    if !path.is_file() {
        return Ok(HashMap::new());
    }
    let bytes = fs::read(&path).map_err(|err| format!("read {}: {err}", path.display()))?;
    serde_json::from_slice(&bytes).map_err(|err| format!("parse {}: {err}", path.display()))
}

fn current_state<R: Runtime>(window: &Window<R>) -> Result<WindowState, String> {
    let size = window.inner_size().map_err(|err| err.to_string())?;
    let position = window.outer_position().map_err(|err| err.to_string())?;
    Ok(WindowState {
        width: size.width,
        height: size.height,
        x: position.x,
        y: position.y,
        prev_x: position.x,
        prev_y: position.y,
        maximized: window.is_maximized().map_err(|err| err.to_string())?,
        visible: window.is_visible().map_err(|err| err.to_string())?,
        decorated: window.is_decorated().map_err(|err| err.to_string())?,
        fullscreen: window.is_fullscreen().map_err(|err| err.to_string())?,
    })
}

fn update_state<R: Runtime>(window: &Window<R>, state: &mut WindowState) -> Result<(), String> {
    let maximized = window.is_maximized().map_err(|err| err.to_string())?;
    let minimized = window.is_minimized().map_err(|err| err.to_string())?;

    state.maximized = maximized;
    state.fullscreen = window.is_fullscreen().map_err(|err| err.to_string())?;
    state.decorated = window.is_decorated().map_err(|err| err.to_string())?;
    state.visible = window.is_visible().map_err(|err| err.to_string())?;

    if !maximized && !minimized {
        let size = window.inner_size().map_err(|err| err.to_string())?;
        if size.width > 0 && size.height > 0 {
            state.width = size.width;
            state.height = size.height;
        }
        let position = window.outer_position().map_err(|err| err.to_string())?;
        state.x = position.x;
        state.y = position.y;
    }

    Ok(())
}

fn intersects_available_monitor<R: Runtime>(
    window: &Window<R>,
    position: PhysicalPosition<i32>,
    size: PhysicalSize<u32>,
) -> Result<bool, String> {
    let left = i64::from(position.x);
    let top = i64::from(position.y);
    let right = left + i64::from(size.width);
    let bottom = top + i64::from(size.height);

    for monitor in window.available_monitors().map_err(|err| err.to_string())? {
        let monitor_position = monitor.position();
        let monitor_size = monitor.size();
        let monitor_left = i64::from(monitor_position.x);
        let monitor_top = i64::from(monitor_position.y);
        let monitor_right = monitor_left + i64::from(monitor_size.width);
        let monitor_bottom = monitor_top + i64::from(monitor_size.height);
        if right > monitor_left
            && left < monitor_right
            && bottom > monitor_top
            && top < monitor_bottom
        {
            return Ok(true);
        }
    }

    Ok(false)
}

fn restore_window<R: Runtime>(window: &Window<R>, state: &WindowState) -> Result<(), String> {
    if state.width == 0 || state.height == 0 {
        return Ok(());
    }

    window
        .set_decorations(state.decorated)
        .map_err(|err| err.to_string())?;

    // Match tauri-plugin-window-state 2.2.1 ordering: restore size first,
    // then monitor-safe position, followed by maximized/fullscreen/visibility.
    let saved_size = PhysicalSize::new(state.width, state.height);
    window.set_size(saved_size).map_err(|err| err.to_string())?;

    let saved_position = PhysicalPosition::new(state.x, state.y);
    if intersects_available_monitor(window, saved_position, saved_size)? {
        let restore_position = if state.maximized {
            PhysicalPosition::new(state.prev_x, state.prev_y)
        } else {
            saved_position
        };
        window
            .set_position(restore_position)
            .map_err(|err| err.to_string())?;
    }

    if state.maximized {
        window.maximize().map_err(|err| err.to_string())?;
    }
    window
        .set_fullscreen(state.fullscreen)
        .map_err(|err| err.to_string())?;
    if state.visible {
        window.show().map_err(|err| err.to_string())?;
        window.set_focus().map_err(|err| err.to_string())?;
    } else {
        window.hide().map_err(|err| err.to_string())?;
    }

    Ok(())
}

/// Load and manage the portable cache during the portable plugin's setup hook.
///
/// This deliberately does not restore any window. The official
/// tauri-plugin-window-state loads its cache during plugin setup and restores in
/// `on_window_ready`. PDF_Tunner mirrors that lifecycle while changing only the
/// persistence path.
pub fn initialize<R: Runtime>(app: &AppHandle<R>) -> Result<(), String> {
    if env::var_os("PDF_TUNNER_PORTABLE_ROOT").is_none() {
        return Ok(());
    }

    let cache = PortableWindowStateCache(Arc::new(Mutex::new(load_state()?)));
    let _ = app.manage(cache);
    Ok(())
}

/// Restore one native Tauri Window and attach state listeners.
///
/// `on_window_ready` yields `Window<R>` before the corresponding WebviewWindow
/// is guaranteed to be discoverable through `get_webview_window()`. The official
/// tauri-plugin-window-state 2.2.1 therefore restores directly on `Window<R>`;
/// portable mode follows the same contract.
pub fn track_window<R: Runtime>(window: &Window<R>) -> Result<(), String> {
    if env::var_os("PDF_TUNNER_PORTABLE_ROOT").is_none() {
        return Ok(());
    }

    let cache = window.state::<PortableWindowStateCache>().0.clone();
    let label = window.label().to_string();
    let restored = cache
        .lock()
        .map_err(|_| "portable window-state cache lock poisoned".to_string())?
        .get(&label)
        .cloned();

    if let Some(state) = restored.as_ref() {
        restore_window(window, state)?;
    }

    {
        let mut states = cache
            .lock()
            .map_err(|_| "portable window-state cache lock poisoned".to_string())?;
        states
            .entry(label.clone())
            .or_insert(current_state(window)?);
    }

    let window_for_events = window.clone();
    window.on_window_event(move |event| match event {
        WindowEvent::CloseRequested { .. } => {
            if let Ok(mut states) = cache.lock() {
                if let Some(state) = states.get_mut(&label) {
                    let _ = update_state(&window_for_events, state);
                }
            }
        }
        WindowEvent::Moved(position)
            if !window_for_events.is_minimized().unwrap_or_default() =>
        {
            if let Ok(mut states) = cache.lock() {
                if let Some(state) = states.get_mut(&label) {
                    state.prev_x = state.x;
                    state.prev_y = state.y;
                    state.x = position.x;
                    state.y = position.y;
                }
            }
        }
        WindowEvent::Resized(size) => {
            let maximized = window_for_events.is_maximized().unwrap_or_default();
            let minimized = window_for_events.is_minimized().unwrap_or_default();
            if !maximized && !minimized && size.width > 0 && size.height > 0 {
                if let Ok(mut states) = cache.lock() {
                    if let Some(state) = states.get_mut(&label) {
                        state.width = size.width;
                        state.height = size.height;
                    }
                }
            }
        }
        _ => {}
    });

    Ok(())
}

/// Defensive final capture used by the existing RunEvent close path once the
/// WebviewWindow is available. Core tracking/restoration itself is native-Window
/// based and does not depend on this conversion.
pub fn capture_window<R: Runtime>(window: &WebviewWindow<R>) -> Result<(), String> {
    if env::var_os("PDF_TUNNER_PORTABLE_ROOT").is_none() {
        return Ok(());
    }

    let native_window = window.as_ref().window();
    let cache = native_window.state::<PortableWindowStateCache>();
    let mut states = cache
        .0
        .lock()
        .map_err(|_| "portable window-state cache lock poisoned".to_string())?;
    let state = states
        .entry(native_window.label().to_string())
        .or_insert(current_state(&native_window)?);
    update_state(&native_window, state)
}

pub fn save<R: Runtime>(app: &AppHandle<R>) -> Result<PathBuf, String> {
    let path = portable_state_path()?;
    let cache = app.state::<PortableWindowStateCache>();
    let states = cache
        .0
        .lock()
        .map_err(|_| "portable window-state cache lock poisoned".to_string())?;
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .map_err(|err| format!("create {}: {err}", parent.display()))?;
    }
    let json = serde_json::to_vec_pretty(&*states).map_err(|err| err.to_string())?;
    fs::write(&path, json).map_err(|err| format!("write {}: {err}", path.display()))?;
    Ok(path)
}

#[cfg(test)]
mod tests {
    use super::WindowState;

    #[test]
    fn window_state_json_keeps_upstream_shape() {
        let state = WindowState {
            width: 1280,
            height: 800,
            x: 40,
            y: 50,
            prev_x: 30,
            prev_y: 35,
            maximized: true,
            visible: true,
            decorated: true,
            fullscreen: false,
        };
        let value = serde_json::to_value(state).expect("serialize window state");
        for key in [
            "width",
            "height",
            "x",
            "y",
            "prev_x",
            "prev_y",
            "maximized",
            "visible",
            "decorated",
            "fullscreen",
        ] {
            assert!(value.get(key).is_some(), "missing {key}");
        }
    }

    #[test]
    fn default_state_matches_upstream_visibility_and_decorations() {
        let state = WindowState::default();
        assert!(state.visible);
        assert!(state.decorated);
        assert!(!state.maximized);
        assert!(!state.fullscreen);
    }
}
