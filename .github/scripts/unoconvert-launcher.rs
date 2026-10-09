use std::{
    env,
    ffi::OsString,
    fs,
    path::{Path, PathBuf},
    process::{self, Command},
    time::{SystemTime, UNIX_EPOCH},
};

fn fail(message: impl AsRef<str>, code: i32) -> ! {
    eprintln!("{}", message.as_ref());
    process::exit(code);
}

fn percent_encode_path(path: &Path) -> String {
    let normalized = path.to_string_lossy().replace('\\', "/");
    let mut encoded = String::with_capacity(normalized.len() + 16);
    for byte in normalized.as_bytes() {
        match *byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' | b'/' | b':' => {
                encoded.push(*byte as char)
            }
            other => encoded.push_str(&format!("%{other:02X}")),
        }
    }
    format!("file:///{encoded}")
}

fn move_or_copy(source: &Path, destination: &Path) -> std::io::Result<()> {
    if source == destination {
        return Ok(());
    }
    if destination.exists() {
        fs::remove_file(destination)?;
    }
    match fs::rename(source, destination) {
        Ok(()) => Ok(()),
        Err(_) => {
            fs::copy(source, destination)?;
            fs::remove_file(source)?;
            Ok(())
        }
    }
}

fn consume_value(args: &[OsString], index: &mut usize, option: &str) -> OsString {
    *index += 1;
    if *index >= args.len() {
        fail(format!("Missing value for {option}"), 2);
    }
    args[*index].clone()
}

fn main() {
    let current_exe = env::current_exe().unwrap_or_else(|error| {
        fail(
            format!("PDF_Tunner unoconvert shim could not resolve its executable path: {error}"),
            126,
        )
    });
    let bin_dir = current_exe
        .parent()
        .unwrap_or_else(|| fail("unoconvert.exe has no parent directory", 126));
    let tools_dir = bin_dir
        .parent()
        .unwrap_or_else(|| fail("unoconvert.exe is not under tools/bin", 126));
    let portable_root = tools_dir
        .parent()
        .unwrap_or_else(|| fail("Unable to resolve PDF_Tunner portable root", 126));
    let libreoffice_program = tools_dir.join("libreoffice").join("program");
    let soffice_com = libreoffice_program.join("soffice.com");
    let soffice_exe = libreoffice_program.join("soffice.exe");
    let soffice = if soffice_com.is_file() {
        soffice_com
    } else {
        soffice_exe
    };
    if !soffice.is_file() {
        fail(
            format!("Bundled LibreOffice launcher is missing: {}", soffice.display()),
            126,
        );
    }

    let args: Vec<OsString> = env::args_os().skip(1).collect();
    if args.iter().any(|arg| {
        let text = arg.to_string_lossy();
        text == "--version" || text == "-V"
    }) {
        let version_file = tools_dir.join("libreoffice").join("VERSION.txt");
        let version = fs::read_to_string(&version_file)
            .map(|text| text.trim().to_string())
            .unwrap_or_else(|_| "unknown".to_string());
        println!("PDF_Tunner unoconvert compatibility shim 1.0 (LibreOffice {version})");
        return;
    }
    if args.iter().any(|arg| {
        let text = arg.to_string_lossy();
        text == "--help" || text == "-h"
    }) {
        println!("Usage: unoconvert [--host H] [--port P] [--host-location L] [--protocol P] --convert-to FORMAT [--input-filter FILTER] INPUT OUTPUT");
        return;
    }

    let mut convert_to: Option<OsString> = None;
    let mut input_filter: Option<OsString> = None;
    let mut positionals: Vec<OsString> = Vec::new();
    let mut index = 0usize;
    while index < args.len() {
        let arg = args[index].to_string_lossy();
        match arg.as_ref() {
            "--host" | "--port" | "--host-location" | "--protocol" => {
                let _ = consume_value(&args, &mut index, &arg);
            }
            "--convert-to" => {
                convert_to = Some(consume_value(&args, &mut index, "--convert-to"));
            }
            "--input-filter" => {
                input_filter = Some(consume_value(&args, &mut index, "--input-filter"));
            }
            _ if arg.starts_with("--host=")
                || arg.starts_with("--port=")
                || arg.starts_with("--host-location=")
                || arg.starts_with("--protocol=") => {}
            _ if arg.starts_with("--convert-to=") => {
                convert_to = Some(OsString::from(&arg["--convert-to=".len()..]));
            }
            _ if arg.starts_with("--input-filter=") => {
                input_filter = Some(OsString::from(&arg["--input-filter=".len()..]));
            }
            _ if arg.starts_with('-') => fail(format!("Unsupported unoconvert option: {arg}"), 2),
            _ => positionals.push(args[index].clone()),
        }
        index += 1;
    }

    let convert_to = convert_to.unwrap_or_else(|| fail("Missing --convert-to", 2));
    if positionals.len() != 2 {
        fail(
            format!(
                "Expected INPUT and OUTPUT, got {} positional arguments",
                positionals.len()
            ),
            2,
        );
    }
    let input = PathBuf::from(positionals[0].clone());
    let output = PathBuf::from(positionals[1].clone());
    if !input.is_file() {
        fail(format!("Input file does not exist: {}", input.display()), 2);
    }
    let output_parent = output
        .parent()
        .filter(|path| !path.as_os_str().is_empty())
        .unwrap_or_else(|| Path::new("."));
    if let Err(error) = fs::create_dir_all(output_parent) {
        fail(
            format!(
                "Unable to create output directory {}: {error}",
                output_parent.display()
            ),
            126,
        );
    }

    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_nanos())
        .unwrap_or(0);
    let profile = portable_root
        .join("p")
        .join(format!("u-{}-{stamp}", process::id()));
    let temp = portable_root.join("data").join("tmp").join("libreoffice");
    if let Err(error) = fs::create_dir_all(&profile) {
        fail(
            format!(
                "Unable to create package-local LibreOffice profile {}: {error}",
                profile.display()
            ),
            126,
        );
    }
    if let Err(error) = fs::create_dir_all(&temp) {
        let _ = fs::remove_dir_all(&profile);
        fail(
            format!(
                "Unable to create package-local LibreOffice temp {}: {error}",
                temp.display()
            ),
            126,
        );
    }

    let profile_uri = percent_encode_path(&profile);
    let mut command = Command::new(&soffice);
    command
        .arg(format!("-env:UserInstallation={profile_uri}"))
        .arg("--headless")
        .arg("--nologo");
    if let Some(filter) = &input_filter {
        command.arg(OsString::from(format!(
            "--infilter={}",
            filter.to_string_lossy()
        )));
    }
    command
        .arg("--convert-to")
        .arg(&convert_to)
        .arg("--outdir")
        .arg(output_parent)
        .arg(&input)
        .env("TEMP", &temp)
        .env("TMP", &temp);

    let status = match command.status() {
        Ok(status) => status,
        Err(error) => {
            let _ = fs::remove_dir_all(&profile);
            fail(
                format!(
                    "Unable to start bundled LibreOffice through {}: {error}",
                    soffice.display()
                ),
                126,
            );
        }
    };
    if !status.success() {
        let code = status.code().unwrap_or(1);
        let _ = fs::remove_dir_all(&profile);
        process::exit(code);
    }

    let convert_text = convert_to.to_string_lossy();
    let extension = convert_text.split(':').next().unwrap_or("").trim();
    if extension.is_empty() {
        let _ = fs::remove_dir_all(&profile);
        fail("Unable to derive output extension from --convert-to", 2);
    }
    let stem = input
        .file_stem()
        .unwrap_or_else(|| fail("Input file has no filename stem", 2));
    let generated = output_parent.join(stem).with_extension(extension);
    if !generated.is_file() {
        let deadline = std::time::Instant::now() + std::time::Duration::from_secs(15);
        while std::time::Instant::now() < deadline && !generated.is_file() {
            std::thread::sleep(std::time::Duration::from_millis(200));
        }
    }
    if !generated.is_file() {
        let _ = fs::remove_dir_all(&profile);
        fail(
            format!(
                "LibreOffice exited successfully but expected output was not produced: {}",
                generated.display()
            ),
            1,
        );
    }
    if let Err(error) = move_or_copy(&generated, &output) {
        let _ = fs::remove_dir_all(&profile);
        fail(
            format!(
                "Unable to place converted output at {}: {error}",
                output.display()
            ),
            1,
        );
    }
    let _ = fs::remove_dir_all(&profile);
}
