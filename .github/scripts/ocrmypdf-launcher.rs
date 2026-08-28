use std::{env, fs, process::{self, Command}};

fn main() {
    let current_exe = match env::current_exe() {
        Ok(path) => path,
        Err(error) => {
            eprintln!("PDF_Tunner OCRmyPDF launcher could not resolve its executable path: {error}");
            process::exit(126);
        }
    };
    let python_root = match current_exe.parent() {
        Some(path) => path,
        None => {
            eprintln!("PDF_Tunner OCRmyPDF launcher has no parent directory.");
            process::exit(126);
        }
    };
    let python = python_root.join("python.exe");
    if !python.is_file() {
        eprintln!("Bundled Python runtime is missing: {}", python.display());
        process::exit(126);
    }
    let portable_root = python_root.parent().and_then(|tools| tools.parent()).map(|path| path.to_path_buf()).unwrap_or_else(|| python_root.to_path_buf());
    let temp = portable_root.join("data").join("tmp").join("ocrmypdf");
    let pycache = portable_root.join("data").join("python-cache");
    if let Err(error) = fs::create_dir_all(&temp) {
        eprintln!("Unable to create package-local OCRmyPDF temp directory {}: {error}", temp.display());
        process::exit(126);
    }
    if let Err(error) = fs::create_dir_all(&pycache) {
        eprintln!("Unable to create package-local Python cache directory {}: {error}", pycache.display());
        process::exit(126);
    }
    let status = match Command::new(&python)
        .arg("-m")
        .arg("ocrmypdf")
        .args(env::args_os().skip(1))
        .env("TEMP", &temp)
        .env("TMP", &temp)
        .env("PYTHONPYCACHEPREFIX", &pycache)
        .status()
    {
        Ok(status) => status,
        Err(error) => {
            eprintln!("Unable to start bundled OCRmyPDF through {}: {error}", python.display());
            process::exit(126);
        }
    };
    process::exit(status.code().unwrap_or(1));
}
