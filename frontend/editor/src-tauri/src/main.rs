// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

#[cfg(target_os = "windows")]
fn path_is_network_location(path: &std::path::Path) -> bool {
  use std::path::{Component, Prefix};
  use windows::{
    core::PCWSTR,
    Win32::Storage::FileSystem::GetDriveTypeW,
  };

  let Some(Component::Prefix(prefix_component)) = path.components().next() else {
    return false;
  };

  match prefix_component.kind() {
    Prefix::UNC(_, _) | Prefix::VerbatimUNC(_, _) => true,
    Prefix::Disk(letter) | Prefix::VerbatimDisk(letter) => {
      let drive_root = format!("{}:\\", char::from(letter));
      let wide = drive_root.encode_utf16().chain(std::iter::once(0)).collect::<Vec<_>>();
      // Win32 GetDriveTypeW returns 4 for DRIVE_REMOTE.
      unsafe { GetDriveTypeW(PCWSTR(wide.as_ptr())) == 4 }
    }
    Prefix::Verbatim(_) | Prefix::DeviceNS(_) => false,
  }
}

#[cfg(target_os = "windows")]
fn ensure_fixed_webview2_appcontainer_acl(runtime: &std::path::Path) -> Result<(), String> {
  use std::process::Command;

  // Microsoft requires these AppContainer read/execute grants for unpackaged
  // Win32 apps using Fixed WebView2 120+ on Windows 10. They are harmless and
  // idempotent on Windows 11, so apply them whenever portable mode is active.
  for sid in ["S-1-15-2-2", "S-1-15-2-1"] {
    let grant = format!("*{sid}:(OI)(CI)(RX)");
    let output = Command::new("icacls.exe")
      .arg(runtime)
      .arg("/grant")
      .arg(&grant)
      .output()
      .map_err(|error| format!("failed to launch icacls.exe for {sid}: {error}"))?;

    if !output.status.success() {
      return Err(format!(
        "icacls.exe failed for {sid} with status {}. stdout: {} stderr: {}",
        output.status,
        String::from_utf8_lossy(&output.stdout).trim(),
        String::from_utf8_lossy(&output.stderr).trim()
      ));
    }
  }

  Ok(())
}

#[cfg(target_os = "windows")]
fn fail_portable_bootstrap(data: &std::path::Path, message: &str) -> ! {
  use std::fs;

  let logs = data.join("logs");
  let _ = fs::create_dir_all(&logs);
  let _ = fs::write(logs.join("portable-bootstrap-error.log"), format!("{message}\n"));
  std::process::exit(2);
}

#[cfg(target_os = "windows")]
fn configure_pdf_tunner_portable_environment() {
  use std::{env, fs};

  let Ok(executable) = env::current_exe() else {
    return;
  };
  let Some(root) = executable.parent() else {
    return;
  };

  // The marker makes portable behaviour explicit and keeps normal upstream
  // development/build runs unchanged.
  if !root.join("PDF_TUNNER_PORTABLE").is_file() {
    return;
  }

  let data = root.join("data");
  let calibre_config = data.join("calibre");
  let java_temp = data.join("tmp");
  let webview2_data = data.join("webview2");
  let fixed_webview2 = root.join("runtime").join("webview2").join("fixed");
  let _ = fs::create_dir_all(&data);
  let _ = fs::create_dir_all(&calibre_config);
  let _ = fs::create_dir_all(&java_temp);
  let _ = fs::create_dir_all(&webview2_data);

  if path_is_network_location(root) {
    fail_portable_bootstrap(
      &data,
      "Microsoft Fixed WebView2 Runtime cannot run from a network or UNC location. Move PDF_Tunner to a local drive.",
    );
  }

  if !fixed_webview2.join("msedgewebview2.exe").is_file() {
    fail_portable_bootstrap(
      &data,
      &format!(
        "Bundled Microsoft Fixed WebView2 Runtime is missing: {}",
        fixed_webview2.display()
      ),
    );
  }

  if let Err(error) = ensure_fixed_webview2_appcontainer_acl(&fixed_webview2) {
    fail_portable_bootstrap(
      &data,
      &format!("Unable to prepare Microsoft Fixed WebView2 Runtime permissions: {error}"),
    );
  }

  // Do not rewrite Windows profile variables here. Tauri/WebView2 is native
  // infrastructure and must initialize against the real Windows profile.
  // Stirling-owned backend state is redirected by utils::app_data_dir().
  env::set_var("PDF_TUNNER_PORTABLE_ROOT", root);
  env::set_var("PDF_TUNNER_PORTABLE_DATA_ROOT", &data);

  // The browser executable itself is package-local and version-pinned. The user
  // profile remains independently redirected so browser state never belongs in
  // the immutable runtime folder.
  env::set_var("WEBVIEW2_BROWSER_EXECUTABLE_FOLDER", &fixed_webview2);
  env::set_var("WEBVIEW2_USER_DATA_FOLDER", &webview2_data);

  // JAVA_TOOL_OPTIONS is intentionally Java-specific: the native Tauri/WebView2
  // process keeps the real Windows TEMP/TMP, while bundled Java and its Java temp
  // APIs resolve inside the portable tree. Quotes preserve paths containing spaces.
  env::set_var(
    "JAVA_TOOL_OPTIONS",
    format!("-Djava.io.tmpdir=\"{}\"", java_temp.display()),
  );

  let tools = root.join("tools");
  let tool_paths = [
    tools.join("bin"),
    tools.join("python"),
    tools.join("python").join("Scripts"),
    tools.join("libreoffice").join("program"),
    tools.join("tesseract"),
    tools.join("ghostscript").join("bin"),
    tools.join("qpdf").join("bin"),
    tools.join("poppler").join("Library").join("bin"),
    tools.join("imagemagick"),
    tools.join("calibre"),
    tools.join("pngquant"),
    tools.join("unpaper"),
    tools.join("rar"),
    tools.join("jbig2enc"),
  ];

  let mut path_entries = tool_paths
    .into_iter()
    .filter(|path| path.is_dir())
    .collect::<Vec<_>>();

  if let Some(current_path) = env::var_os("PATH") {
    path_entries.extend(env::split_paths(&current_path));
  }

  if let Ok(portable_path) = env::join_paths(path_entries) {
    env::set_var("PATH", portable_path);
  }

  let tessdata = tools.join("tesseract").join("tessdata");
  if tessdata.is_dir() {
    env::set_var("TESSDATA_PREFIX", tessdata);
  }

  env::set_var("CALIBRE_CONFIG_DIRECTORY", calibre_config);
}

#[cfg(not(target_os = "windows"))]
fn configure_pdf_tunner_portable_environment() {}

fn main() {
  configure_pdf_tunner_portable_environment();
  app_lib::run();
}
