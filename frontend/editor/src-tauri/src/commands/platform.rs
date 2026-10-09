use serde::Serialize;

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum DesktopOS {
    MacOS,
    Windows,
    Linux,
    Unknown,
}

#[tauri::command]
pub fn get_desktop_os() -> DesktopOS {
    match std::env::consts::OS {
        "macos" => DesktopOS::MacOS,
        "windows" => DesktopOS::Windows,
        "linux" => DesktopOS::Linux,
        _ => DesktopOS::Unknown,
    }
}

/// True only for native portable Windows execution as marked by the bootstrap.
#[tauri::command]
pub fn is_pdf_tunner_portable() -> bool {
    std::env::var_os("PDF_TUNNER_PORTABLE_ROOT").is_some()
}
