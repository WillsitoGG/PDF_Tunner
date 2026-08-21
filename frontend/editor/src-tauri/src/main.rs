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
  let roaming = data.join("appdata").join("Roaming");
  let local = data.join("appdata").join("Local");
  let program_data = data.join("programdata");
  let home = data.join("home");
  let temp = data.join("temp");
  let cache = data.join("cache");

  for directory in [&roaming, &local, &program_data, &home, &temp, &cache] {
    let _ = fs::create_dir_all(directory);
  }

  // Set these before Tauri or any plugin/backend thread is created so all
  // child processes inherit package-local paths.
  env::set_var("PDF_TUNNER_PORTABLE_ROOT", root);
  env::set_var("APPDATA", &roaming);
  env::set_var("LOCALAPPDATA", &local);
  env::set_var("PROGRAMDATA", &program_data);
  env::set_var("USERPROFILE", &home);
  env::set_var("HOME", &home);
  env::set_var("TEMP", &temp);
  env::set_var("TMP", &temp);
  env::set_var("XDG_CACHE_HOME", &cache);

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

  let calibre_config = data.join("calibre");
  let _ = fs::create_dir_all(&calibre_config);
  env::set_var("CALIBRE_CONFIG_DIRECTORY", calibre_config);
}

#[cfg(not(target_os = "windows"))]
fn configure_pdf_tunner_portable_environment() {}

fn main() {
  configure_pdf_tunner_portable_environment();
  app_lib::run();
}
