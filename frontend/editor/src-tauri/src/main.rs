// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

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
  let _ = fs::create_dir_all(&data);
  let _ = fs::create_dir_all(&calibre_config);
  let _ = fs::create_dir_all(&java_temp);
  let _ = fs::create_dir_all(&webview2_data);

  // Do not rewrite Windows profile variables here. Tauri/WebView2 is native
  // infrastructure and must initialize against the real Windows profile.
  // Stirling-owned backend state is redirected by utils::app_data_dir().
  env::set_var("PDF_TUNNER_PORTABLE_ROOT", root);

  // WebView2 supports a component-specific user-data override. Keep the native
  // Windows profile intact while moving cookies, IndexedDB, caches and browser
  // profile state into the portable tree.
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
