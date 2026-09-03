use std::{
    env,
    ffi::OsString,
    fs,
    path::{Path, PathBuf},
    process::{Command, ExitCode},
    time::{SystemTime, UNIX_EPOCH},
};

fn portable_root() -> Result<PathBuf, String> {
    let exe = env::current_exe().map_err(|e| format!("cannot resolve launcher path: {e}"))?;
    let bin = exe.parent().ok_or("launcher has no parent directory")?;
    let tools = bin.parent().ok_or("tools/bin layout is invalid")?;
    tools
        .parent()
        .map(Path::to_path_buf)
        .ok_or_else(|| "portable root cannot be resolved".to_string())
}

fn main() -> ExitCode {
    match run() {
        Ok(code) => ExitCode::from(code as u8),
        Err(message) => {
            eprintln!("PDF_Tunner Calibre launcher error: {message}");
            ExitCode::from(127)
        }
    }
}

fn run() -> Result<i32, String> {
    let root = portable_root()?;
    let backend = root.join("tools").join("calibre").join("ebook-convert.exe");
    if !backend.is_file() {
        return Err(format!("bundled ebook-convert.exe is missing: {}", backend.display()));
    }

    let config = root.join("data").join("calibre").join("config");
    let cache = root.join("data").join("calibre").join("cache");
    let temp_parent = root.join("data").join("tmp").join("calibre");
    fs::create_dir_all(&config).map_err(|e| format!("cannot create Calibre config directory: {e}"))?;
    fs::create_dir_all(&cache).map_err(|e| format!("cannot create Calibre cache directory: {e}"))?;
    fs::create_dir_all(&temp_parent).map_err(|e| format!("cannot create Calibre temp parent: {e}"))?;

    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|e| format!("system clock error: {e}"))?
        .as_millis();
    let invocation_temp = temp_parent.join(format!("run-{}-{stamp}", std::process::id()));
    fs::create_dir_all(&invocation_temp).map_err(|e| format!("cannot create Calibre invocation temp: {e}"))?;

    let args: Vec<OsString> = env::args_os().skip(1).collect();
    let status = Command::new(&backend)
        .args(args)
        .env("CALIBRE_CONFIG_DIRECTORY", &config)
        .env("CALIBRE_CACHE_DIRECTORY", &cache)
        .env("CALIBRE_TEMP_DIR", &invocation_temp)
        .env("CALIBRE_NO_DEFAULT_PROGRAMS", "1")
        .env("TEMP", &invocation_temp)
        .env("TMP", &invocation_temp)
        .status()
        .map_err(|e| format!("failed to start bundled ebook-convert.exe: {e}"));

    let cleanup = fs::remove_dir_all(&invocation_temp);
    if let Err(error) = cleanup {
        if invocation_temp.exists() {
            return Err(format!("failed to clean Calibre invocation temp {}: {error}", invocation_temp.display()));
        }
    }
    if temp_parent.is_dir() {
        if let Ok(mut entries) = fs::read_dir(&temp_parent) {
            if entries.next().is_none() {
                let _ = fs::remove_dir(&temp_parent);
            }
        }
    }

    let status = status?;
    Ok(status.code().unwrap_or(1))
}
