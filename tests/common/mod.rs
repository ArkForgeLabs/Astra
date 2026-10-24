//! Shared harness for Astra integration tests.
//!
//! These tests spawn the built `astra` binary as a subprocess — the flag
//! system (`ALLOW_LIST`) is process-global, so every configuration needs a
//! fresh process. A polling/timeout runner is used because a VM bug can
//! manifest as an infinite hang (it has before), and the runtime also exits
//! 0 on script errors, so assertions are made on captured output, not exit
//! codes.

// crates that include this module only use part of it
#![allow(dead_code)]

use std::io::Read;
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};

pub const ASTRA_EXE: &str = env!("CARGO_BIN_EXE_astra");
pub const REPO_ROOT: &str = env!("CARGO_MANIFEST_DIR");

pub struct RunOutcome {
    pub status: Option<i32>,
    pub stdout: String,
    pub stderr: String,
    pub hung: bool,
}

/// Runs the astra binary with the given args in `cwd`, killing it after
/// `timeout` seconds. The process hanging is itself an interesting (failing)
/// outcome, so it is reported instead of blocking forever.
pub fn run_with_timeout(args: &[&str], cwd: &std::path::Path, timeout: u64) -> RunOutcome {
    let mut child = Command::new(ASTRA_EXE)
        .args(args)
        .current_dir(cwd)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("Could not spawn the astra binary");

    let deadline = Instant::now() + Duration::from_secs(timeout);
    let hung = loop {
        match child.try_wait().expect("Could not poll astra process") {
            Some(_) => break false,
            None => {
                if Instant::now() > deadline {
                    break true;
                }
                std::thread::sleep(Duration::from_millis(50));
            }
        }
    };

    if hung {
        let _ = child.kill();
        // drain whatever was produced before the kill
        let stdout = read_pipe(child.stdout.take());
        let stderr = read_pipe(child.stderr.take());
        return RunOutcome {
            status: None,
            stdout,
            stderr,
            hung: true,
        };
    }

    let status = child.wait().expect("Could not reap astra process").code();
    let stdout = read_pipe(child.stdout.take());
    let stderr = read_pipe(child.stderr.take());

    RunOutcome {
        status,
        stdout,
        stderr,
        hung: false,
    }
}

/// Runs an arbitrary command with the same hang protection.
pub fn run_cmd_with_timeout(cmd: &mut Command, timeout: u64) -> RunOutcome {
    let mut child = cmd
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("Could not spawn the command");

    let deadline = Instant::now() + Duration::from_secs(timeout);
    let hung = loop {
        match child.try_wait().expect("Could not poll process") {
            Some(_) => break false,
            None => {
                if Instant::now() > deadline {
                    break true;
                }
                std::thread::sleep(Duration::from_millis(50));
            }
        }
    };

    if hung {
        let _ = child.kill();
        let stdout = read_pipe(child.stdout.take());
        let stderr = read_pipe(child.stderr.take());
        return RunOutcome {
            status: None,
            stdout,
            stderr,
            hung: true,
        };
    }

    let status = child.wait().expect("Could not reap process").code();
    let stdout = read_pipe(child.stdout.take());
    let stderr = read_pipe(child.stderr.take());

    RunOutcome {
        status,
        stdout,
        stderr,
        hung: false,
    }
}

fn read_pipe<T: Read>(pipe: Option<T>) -> String {
    let mut buffer = Vec::new();
    if let Some(mut pipe) = pipe {
        let _ = pipe.read_to_end(&mut buffer);
    }
    String::from_utf8_lossy(&buffer).into_owned()
}

/// Builds a unique temporary directory for a test fixture.
pub fn fixture_dir(label: &str) -> std::path::PathBuf {
    let dir = std::env::temp_dir().join(format!(
        "astra-test-{label}-{}",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("system clock before epoch")
            .as_nanos()
    ));
    std::fs::create_dir_all(&dir).expect("Could not create the fixture directory");
    dir
}

/// Strips ANSI escape sequences (lust colorizes its output).
pub fn strip_ansi(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    let mut chars = text.chars();
    while let Some(c) = chars.next() {
        if c == '\x1b' && chars.next() == Some('[') {
            for c in chars.by_ref() {
                if c.is_ascii_alphabetic() {
                    break;
                }
            }
        } else {
            out.push(c);
        }
    }
    out
}

/// Parses the lust summary line ("N passed and M failed.") from
/// `tests/init.lua`'s final print.
pub fn parse_lust_summary(output: &str) -> (u64, u64) {
    let cleaned = strip_ansi(output);
    let needle = " failed.";
    let summary_line = cleaned
        .lines()
        .rev()
        .find(|line| line.contains(" passed and ") && line.contains(needle));

    let line = summary_line.unwrap_or_else(|| {
        panic!(
            "Could not find the lust summary in the output:\n{}",
            cleaned
        )
    });

    // format: "<green>P passed and" ... "<red>E" ... " failed."
    let tokens: Vec<&str> = line.split_whitespace().collect();
    let fail_index = tokens
        .iter()
        .position(|t| *t == "failed.")
        .unwrap_or_else(|| panic!("Malformed lust summary line: {line}"));

    let errors: u64 = tokens[fail_index - 1]
        .parse()
        .unwrap_or_else(|_| panic!("Malformed failure count in lust summary: {line}"));
    let passes: u64 = tokens
        .windows(3)
        .find(|w| w[1] == "passed" && w[2] == "and")
        .and_then(|w| w[0].parse().ok())
        .unwrap_or_else(|| panic!("Malformed pass count in lust summary: {line}"));

    (passes, errors)
}

/// Asserts the process did not hang before making any other assertion.
#[track_caller]
pub fn assert_not_hung(outcome: &RunOutcome, config: &str) {
    assert!(
        !outcome.hung,
        "astra HUNG (config: {config}):\nstdout:\n{}\nstderr:\n{}",
        outcome.stdout, outcome.stderr
    );
}
