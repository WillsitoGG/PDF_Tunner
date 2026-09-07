use std::{env, fs, path::PathBuf, process};

fn fail(message: &str) -> ! {
    eprintln!("PDF_TUNNER_RAR_PROBE_ERROR={message}");
    process::exit(64);
}

fn main() {
    let executable = env::current_exe().unwrap_or_else(|e| fail(&format!("current_exe: {e}")));
    let log_path = env::var_os("PDF_TUNNER_RAR_PROBE_LOG")
        .map(PathBuf::from)
        .unwrap_or_else(|| fail("PDF_TUNNER_RAR_PROBE_LOG is not set"));
    let args: Vec<_> = env::args_os().skip(1).collect();

    let mut log = format!("EXE={}\nARG_COUNT={}\n", executable.display(), args.len());
    for (index, arg) in args.iter().enumerate() {
        log.push_str(&format!("ARG_{index}={}\n", arg.to_string_lossy()));
    }
    if let Some(parent) = log_path.parent() {
        fs::create_dir_all(parent).unwrap_or_else(|e| fail(&format!("create log dir: {e}")));
    }
    fs::write(&log_path, log).unwrap_or_else(|e| fail(&format!("write probe log: {e}")));

    if args.len() < 5 {
        fail("expected: a -m5 -ep1 <output.cbr> <page...>");
    }
    if args[0].to_string_lossy() != "a" || args[1].to_string_lossy() != "-m5" || args[2].to_string_lossy() != "-ep1" {
        fail("unexpected RAR command prefix");
    }

    let output = PathBuf::from(&args[3]);
    if output.extension().and_then(|v| v.to_str()).map(|v| !v.eq_ignore_ascii_case("cbr")).unwrap_or(true) {
        fail("output is not a .cbr path");
    }
    for page in &args[4..] {
        let page = PathBuf::from(page);
        if !page.is_file() {
            fail(&format!("rendered page does not exist: {}", page.display()));
        }
        if page.extension().and_then(|v| v.to_str()).map(|v| !v.eq_ignore_ascii_case("png")).unwrap_or(true) {
            fail(&format!("rendered page is not PNG: {}", page.display()));
        }
    }

    fs::write(&output, b"PDF_TUNNER_RAR_PROBE_ONLY\n")
        .unwrap_or_else(|e| fail(&format!("write probe output: {e}")));
}
