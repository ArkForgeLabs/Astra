//! Process-level sandbox flag tests.
//!
//! Each test spawns a fresh `astra run` with a specific `--allow`
//! configuration and asserts on the emitted output, mirroring the manual
//! deep-test matrix (see SANDBOX_TESTS.md in the repo history). These run in
//! the default engine; the cross-engine matrix lives in `dev.lua` +
//! the ephemeral harness.

mod common;

use common::{assert_not_hung, fixture_dir, run_cmd_with_timeout, run_with_timeout};

/// Runs a packed binary directly (the packed app is not ASTRA_EXE).
fn run_packed(exe: &std::path::Path, cwd: &std::path::Path, timeout: u64) -> common::RunOutcome {
    let mut cmd = std::process::Command::new(exe);
    cmd.current_dir(cwd);
    run_cmd_with_timeout(&mut cmd, timeout)
}

#[test]
fn full_vm_when_no_flags() {
    let dir = fixture_dir("full-vm");
    let script = dir.join("main.lua");
    std::fs::write(
        &script,
        r#"
print("MARK string_format ok", string.format("%d", 42))
print("MARK table_present", type(table) == "table")
local ok, fs = pcall(require, "fs")
print("MARK fs_require", ok, type(fs))
print("MARK stdlib_table", ASTRA_INTERNAL__STDLIB_TABLE ~= nil)
"#,
    )
    .unwrap();

    let outcome = run_with_timeout(&["run", script.to_str().unwrap()], &dir, 60);
    assert_not_hung(&outcome, "no flags");
    let out = &outcome.stdout;
    assert!(
        out.contains("MARK string_format ok 42"),
        "full VM should have string.format:\n{out}"
    );
    assert!(
        out.contains("MARK fs_require true table"),
        "fs module should load:\n{out}"
    );
    assert!(
        out.contains("MARK stdlib_table true"),
        "STDLIB_TABLE should be exposed in open runtimes:\n{out}"
    );
    assert!(
        out.contains("MARK table_present true"),
        "full VM should have the table lib:\n{out}"
    );
}

#[test]
fn allow_none_stubs_base() {
    let dir = fixture_dir("allow-none");
    let script = dir.join("main.lua");
    // no usable print in this VM; calling it raises and the runtime prints
    // the stub error on stderr — that error text is the assertion target
    std::fs::write(&script, "print(\"should never appear\")\n").unwrap();

    let outcome = run_with_timeout(
        &["run", "--allow", "none", script.to_str().unwrap()],
        &dir,
        60,
    );
    assert_not_hung(&outcome, "--allow none");
    let err = &outcome.stderr;
    assert!(
        err.contains("print is disabled in sandbox mode"),
        "print must be stubbed with a clear message:\n{err}"
    );
    assert!(
        !outcome.stdout.contains("should never appear"),
        "stubbed print must not execute:\n{}",
        outcome.stdout
    );
}

#[test]
fn allow_none_removes_require_and_components() {
    let dir = fixture_dir("allow-none-2");
    let script = dir.join("main.lua");
    std::fs::write(
        &script,
        r#"
-- restricted VM: no string/table libraries, base ops only
local report = ""
local function note(k, v) report = report .. k .. "=" .. tostring(v) .. "|" end
note("require_type", type(require))
local pok, perr = pcall(require, "fs")
note("require_call", pok)
note("require_err", perr)
note("fs_internal", _G["astra_internal__write_file"] ~= nil)
note("crypto_internal", _G["astra_internal__hash"] ~= nil)
note("stdlib_table", ASTRA_INTERNAL__STDLIB_TABLE ~= nil)
note("print_stubbed", select(1, pcall(print, "x")))
error(report)
"#,
    )
    .unwrap();

    let outcome = run_with_timeout(
        &["run", "--allow", "none", script.to_str().unwrap()],
        &dir,
        60,
    );
    assert_not_hung(&outcome, "--allow none (components)");
    let err = &outcome.stderr;
    assert!(
        err.contains("require_type=nil"),
        "require must be nil in restricted VMs:\n{err}"
    );
    assert!(
        err.contains("require_call=false"),
        "require(nil) call must fail:\n{err}"
    );
    assert!(
        err.contains("fs_internal=false"),
        "no fs internals may be registered:\n{err}"
    );
    assert!(
        err.contains("crypto_internal=false"),
        "no crypto internals may be registered:\n{err}"
    );
    assert!(
        err.contains("stdlib_table=false"),
        "STDLIB_TABLE must be absent in restricted VMs:\n{err}"
    );
    assert!(
        err.contains("print_stubbed=false"),
        "print must be a stub (pcall fails) in restricted VMs:\n{err}"
    );
    assert!(
        !err.contains("Could not find the module"),
        "with require removed there is no import fallback path:\n{err}"
    );
}

#[test]
fn single_flag_gating() {
    let dir = fixture_dir("single-flag");
    for (allow, present, absent) in [
        (
            "file-system",
            "astra_internal__write_file",
            "astra_internal__hash",
        ),
        (
            "crypto",
            "astra_internal__hash",
            "astra_internal__write_file",
        ),
        ("utils", "astra_internal__uuid", "astra_internal__hash"),
    ] {
        let script = dir.join(format!("main-{present}.lua"));
        std::fs::write(
            &script,
            format!(
                r#"
error("GATE {present}=" .. tostring(_G["{present}"] ~= nil) .. "," .. tostring(_G["{absent}"] ~= nil))
"#
            ),
        )
        .unwrap();

        let outcome = run_with_timeout(
            &["run", "--allow", allow, script.to_str().unwrap()],
            &dir,
            60,
        );
        assert_not_hung(&outcome, &format!("--allow {allow}"));
        let err = &outcome.stderr;
        assert!(
            err.contains(&format!("GATE {present}=true,false")),
            "--allow {allow}: {present} present, {absent} absent:\n{err}"
        );
    }
}

#[test]
fn import_gates_embedded_modules() {
    let dir = fixture_dir("import-gate");
    let script = dir.join("main.lua");
    std::fs::write(
        &script,
        r#"
-- restricted VM: no string/table libraries, base ops only
local report = ""
local function note(k, v) report = report .. k .. "=" .. tostring(v) .. "|" end
local sok, stores = pcall(require, "stores")
note("stores", sok and type(stores) == "table")
local fok, ferr = pcall(require, "fs")
note("fs", fok)
note("fs_err", ferr)
error(report)
"#,
    )
    .unwrap();

    let outcome = run_with_timeout(
        &["run", "--allow", "import", script.to_str().unwrap()],
        &dir,
        60,
    );
    assert_not_hung(&outcome, "--allow import");
    let err = &outcome.stderr;
    assert!(
        err.contains("stores=true"),
        "unlisted embedded modules follow disk trust:\n{err}"
    );
    assert!(
        err.contains("fs=false"),
        "fs module must be denied without its flag:\n{err}"
    );
    assert!(
        err.contains("fs_err=runtime error: Could not find the module fs"),
        "miss message must be the clean Astra one:\n{err}"
    );
}

#[test]
fn import_with_fs_combination() {
    let dir = fixture_dir("import-fs");
    let script = dir.join("main.lua");
    std::fs::write(
        &script,
        r#"
-- restricted VM: no string/table libraries, base ops only
local report = ""
local function note(k, v) report = report .. k .. "=" .. tostring(v) .. "|" end
local fok, fs = pcall(require, "fs")
note("fs", fok and type(fs) == "table")
local hok, herr = pcall(require, "http")
note("http", hok)
note("http_err", herr)
error(report)
"#,
    )
    .unwrap();

    let outcome = run_with_timeout(
        &[
            "run",
            "--allow",
            "import,file-system",
            script.to_str().unwrap(),
        ],
        &dir,
        60,
    );
    assert_not_hung(&outcome, "--allow import,file-system");
    let err = &outcome.stderr;
    assert!(
        err.contains("fs=true"),
        "fs should load with both flags:\n{err}"
    );
    assert!(
        err.contains("http_err=runtime error: Could not find the module http"),
        "http miss must be clean:\n{err}"
    );
}

#[test]
fn explicit_full_list_is_restricted_vm() {
    let dir = fixture_dir("full-list");
    let script = dir.join("main.lua");
    std::fs::write(
        &script,
        r#"
print("MARK astra_print", print ~= nil)
print("MARK string_lib", type(string) == "table")
print("MARK fs", pcall(require, "fs"))
"#,
    )
    .unwrap();

    let outcome = run_with_timeout(
        &[
            "run",
            "--allow",
            "globals,import,utils,serde,http-server,http-client,database,datetime,crypto,file-system,templates",
            script.to_str().unwrap(),
        ],
        &dir,
        60,
    );
    assert_not_hung(&outcome, "explicit full list");
    let out = &outcome.stdout;
    assert!(
        out.contains("MARK astra_print true"),
        "Astra print installed:\n{out}"
    );
    assert!(
        out.contains("MARK string_lib false"),
        "explicit full list must still be a restricted (NONE) VM, unlike no-flag runs:\n{out}"
    );
    assert!(
        out.contains("MARK fs true"),
        "imports gated by Import flag which is present:\n{out}"
    );
}

#[test]
fn getenv_nil_on_missing_in_restricted() {
    let dir = fixture_dir("getenv-nil");
    let script = dir.join("main.lua");
    std::fs::write(
        &script,
        r#"
local ok, value = pcall(getenv, "ASTRA_TEST_DEFINITELY_UNSET_VAR_9127")
print("MARK getenv_missing", ok, value)
print("MARK getenv_idiom", tostring(getenv("ASTRA_TEST_DEFINITELY_UNSET_VAR_9127") == nil))
"#,
    )
    .unwrap();

    let outcome = run_with_timeout(
        &["run", "--allow", "globals", script.to_str().unwrap()],
        &dir,
        60,
    );
    assert_not_hung(&outcome, "--allow globals");
    let out = &outcome.stdout;
    assert!(
        out.contains("MARK getenv_missing true nil"),
        "missing env var must return nil in restricted VMs (base os.getenv semantics):\n{out}"
    );
    assert!(
        out.contains("MARK getenv_idiom true"),
        "the `getenv(x) or default` idiom must work:\n{out}"
    );
}

#[test]
fn missing_file_is_clean_error() {
    let dir = fixture_dir("missing-file");
    let outcome = run_with_timeout(&["run", "definitely-not-a-file.lua"], &dir, 60);
    assert_not_hung(&outcome, "missing file");
    assert_eq!(outcome.status, Some(1), "must exit 1:\n{}", outcome.stderr);
    assert!(
        outcome.stderr.contains("Could not find any file to run"),
        "clean CLI error expected, no panic:\n{}",
        outcome.stderr
    );
    assert!(
        !outcome.stderr.contains("panicked"),
        "must not panic:\n{}",
        outcome.stderr
    );
}

#[test]
fn pack_lifecycle() {
    let dir = fixture_dir("pack");
    std::fs::write(
        dir.join("helper.lua"),
        "local helper = {}\nfunction helper.greet() return \"hi from embedded helper\" end\nreturn helper\n",
    )
    .unwrap();
    std::fs::write(
        dir.join("init.lua"),
        r#"
local helper = require("helper")
local fs = require("fs")
print("MARK helper", type(helper))
print("MARK greet", helper.greet())
print("MARK fs", type(fs))
print("MARK string_format", pcall(string.format, "full VM: %d", 42))
"#,
    )
    .unwrap();

    let output = dir.join("app");
    // pack from a FOREIGN cwd with an absolute entry path: resolution must
    // not depend on the pack command's working directory
    let pack = run_with_timeout(
        &[
            "pack",
            dir.join("init.lua").to_str().unwrap(),
            "-o",
            output.to_str().unwrap(),
        ],
        dir.parent().unwrap_or(&dir),
        120,
    );
    assert_not_hung(&pack, "pack");
    assert!(
        output.exists(),
        "pack must create the output file:\n{}\n{}",
        pack.stdout,
        pack.stderr
    );

    // run the packed binary from an unrelated CWD
    let foreign = fixture_dir("pack-foreign");
    let packed_copy = foreign.join("app");
    std::fs::copy(&output, &packed_copy).unwrap();

    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(&packed_copy, std::fs::Permissions::from_mode(0o755)).unwrap();
    }

    let run = run_packed(&packed_copy, &foreign, 60);
    assert_not_hung(&run, "packed app");
    assert!(
        run.stdout.contains("MARK helper table"),
        "entry-script-relative imports must be embedded:\n{}",
        run.stdout
    );
    assert!(
        run.stdout.contains("MARK greet hi from embedded helper"),
        "embedded helper must come from the payload:\n{}",
        run.stdout
    );
    assert!(
        run.stdout.contains("MARK fs table"),
        "stdlib fs must serve the packed app:\n{}",
        run.stdout
    );
    assert!(
        run.stdout.contains("MARK string_format true full VM: 42"),
        "packed binaries run in the full VM:\n{}",
        run.stdout
    );

    // ASTRA_BE_ASTRA=true must skip the packed runtime
    let mut child = std::process::Command::new(packed_copy.clone())
        .current_dir(&foreign)
        .env("ASTRA_BE_ASTRA", "true")
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
        .unwrap();
    let deadline = std::time::Instant::now() + std::time::Duration::from_secs(60);
    loop {
        match child.try_wait().unwrap() {
            Some(_) => break,
            None if std::time::Instant::now() > deadline => {
                let _ = child.kill();
                panic!("ASTRA_BE_ASTRA skip run HUNG");
            }
            None => std::thread::sleep(std::time::Duration::from_millis(50)),
        }
    }
    let mut out = String::new();
    if let Some(mut pipe) = child.stdout.take() {
        use std::io::Read;
        let _ = pipe.read_to_string(&mut out);
    }
    let mut err = String::new();
    if let Some(mut pipe) = child.stderr.take() {
        use std::io::Read;
        let _ = pipe.read_to_string(&mut err);
    }
    assert!(
        out.contains("Blazingly Fast") || err.contains("Blazingly Fast"),
        "ASTRA_BE_ASTRA=true must fall back to the CLI banner:\nstdout:\n{out}\nstderr:\n{err}"
    );
    std::fs::remove_dir_all(&foreign).ok();
}

#[test]
fn pack_resolution_matches_runtime() {
    let dir = fixture_dir("pack-parity");
    std::fs::create_dir_all(dir.join("sub")).unwrap();
    std::fs::write(
        dir.join("helper.lua"),
        "local helper = {}\nfunction helper.greet() return \"hi from root helper\" end\nreturn helper\n",
    )
    .unwrap();
    std::fs::write(
        dir.join("sub").join("helper.lua"),
        "local helper = {}\nfunction helper.greet() return \"hi from sub helper\" end\nreturn helper\n",
    )
    .unwrap();

    // entry resolves plain require("helper") — runtime candidates are
    // CWD-first, then the script dir; from the project dir the root helper
    // wins, and pack must embed exactly that snapshot
    std::fs::write(
        dir.join("init.lua"),
        "local helper = require(\"helper\")\nprint(\"MARK greet\", helper.greet())\n",
    )
    .unwrap();

    let output = dir.join("app");
    let pack = run_with_timeout(
        &[
            "pack",
            dir.join("init.lua").to_str().unwrap(),
            "-o",
            output.to_str().unwrap(),
        ],
        dir.parent().unwrap_or(&dir),
        120,
    );
    assert_not_hung(&pack, "parity pack");

    // the unpacked and packed runs must agree (packed run from a foreign CWD)
    let foreign = fixture_dir("pack-parity-foreign");
    let packed_copy = foreign.join("app");
    std::fs::copy(&output, &packed_copy).unwrap();

    let unpacked = run_with_timeout(&["run", "init.lua"], &dir, 60);
    assert_not_hung(&unpacked, "unpacked parity run");

    let packed = run_packed(&packed_copy, &foreign, 60);
    assert_not_hung(&packed, "packed parity run");

    let unpacked_greet = unpacked
        .stdout
        .lines()
        .find(|l| l.contains("MARK greet"))
        .unwrap_or_else(|| panic!("no greet line in unpacked run:\n{}", unpacked.stdout));
    let packed_greet = packed
        .stdout
        .lines()
        .find(|l| l.contains("MARK greet"))
        .unwrap_or_else(|| panic!("no greet line in packed run:\n{}", packed.stdout));
    assert_eq!(
        unpacked_greet.trim(),
        packed_greet.trim(),
        "packed and unpacked runs must resolve the same module (frozen pack snapshot must match the pack-time resolution):\npacked={packed_greet}\nunpacked={unpacked_greet}"
    );
    assert!(
        packed_greet.contains("root helper"),
        "CWD-first runtime rule picked the root helper at pack time:\n{packed_greet}"
    );

    std::fs::remove_dir_all(&foreign).ok();
}
