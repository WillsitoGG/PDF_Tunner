use std::{
    env,
    fs,
    process::{self, Command},
    time::{SystemTime, UNIX_EPOCH},
};

fn fail(message: impl AsRef<str>, code: i32) -> ! {
    eprintln!("{}", message.as_ref());
    process::exit(code);
}

fn main() {
    let current_exe = env::current_exe().unwrap_or_else(|error| {
        fail(
            format!("PDF_Tunner WeasyPrint shim could not resolve its executable path: {error}"),
            126,
        )
    });
    let bin_dir = current_exe
        .parent()
        .unwrap_or_else(|| fail("weasyprint.exe has no parent directory", 126));
    let tools_dir = bin_dir
        .parent()
        .unwrap_or_else(|| fail("weasyprint.exe is not under tools/bin", 126));
    let portable_root = tools_dir
        .parent()
        .unwrap_or_else(|| fail("Unable to resolve PDF_Tunner portable root", 126));
    let backend = tools_dir.join("weasyprint").join("weasyprint.exe");
    if !backend.is_file() {
        fail(
            format!("Bundled WeasyPrint executable is missing: {}", backend.display()),
            126,
        );
    }

    let temp_root = portable_root.join("data").join("tmp").join("weasyprint");
    if let Err(error) = fs::create_dir_all(&temp_root) {
        fail(
            format!(
                "Unable to create package-local WeasyPrint temp root {}: {error}",
                temp_root.display()
            ),
            126,
        );
    }
    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_nanos())
        .unwrap_or(0);
    let invocation_temp = temp_root.join(format!("run-{}-{stamp}", process::id()));
    if let Err(error) = fs::create_dir_all(&invocation_temp) {
        fail(
            format!(
                "Unable to create package-local WeasyPrint invocation temp {}: {error}",
                invocation_temp.display()
            ),
            126,
        );
    }

    let status = Command::new(&backend)
        .args(env::args_os().skip(1))
        .env("TEMP", &invocation_temp)
        .env("TMP", &invocation_temp)
        .env("TMPDIR", &invocation_temp)
        .status();

    let exit_code = match status {
        Ok(status) => status.code().unwrap_or(1),
        Err(error) => {
            let _ = fs::remove_dir_all(&invocation_temp);
            fail(
                format!(
                    "Unable to start bundled WeasyPrint through {}: {error}",
                    backend.display()
                ),
                126,
            );
        }
    };

    if let Err(error) = fs::remove_dir_all(&invocation_temp) {
        eprintln!(
            "PDF_Tunner WeasyPrint shim warning: could not remove invocation temp {}: {error}",
            invocation_temp.display()
        );
        if exit_code == 0 {
            process::exit(125);
        }
    }

    process::exit(exit_code);
}
