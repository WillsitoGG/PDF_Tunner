#![cfg_attr(target_os = "windows", windows_subsystem = "windows")]

use std::{
    env,
    fs,
    path::PathBuf,
    process::{Command, ExitCode},
};

fn fail(message: &str) -> ExitCode {
    eprintln!("PDF_Tunner LibreOffice launcher: {message}");
    ExitCode::from(127)
}

fn portable_root() -> Option<PathBuf> {
    let exe = env::current_exe().ok()?;
    let bin = exe.parent()?;
    let tools = bin.parent()?;
    tools.parent().map(PathBuf::from)
}

fn main() -> ExitCode {
    let Some(root) = portable_root() else {
        return fail("cannot resolve portable root from launcher location");
    };

    let canonical = root
        .join("tools")
        .join("libreoffice")
        .join("program")
        .join("soffice.exe");
    if !canonical.is_file() {
        return fail(&format!("canonical soffice.exe is missing: {}", canonical.display()));
    }

    let temp = root.join("data").join("tmp").join("libreoffice");
    if let Err(error) = fs::create_dir_all(&temp) {
        return fail(&format!("cannot create package-local temp directory: {error}"));
    }

    let mut command = Command::new(&canonical);
    command.args(env::args_os().skip(1));
    command.env("TEMP", &temp);
    command.env("TMP", &temp);

    match command.status() {
        Ok(status) => match status.code() {
            Some(code) if (0..=255).contains(&code) => ExitCode::from(code as u8),
            Some(_) => ExitCode::from(1),
            None => ExitCode::from(1),
        },
        Err(error) => fail(&format!("failed to launch canonical LibreOffice: {error}")),
    }
}
