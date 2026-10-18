//! Runs the full Lua test suite (`tests/init.lua`, lust-based) through the
//! built `astra` binary as part of `cargo test`.
//!
//! The suite runs in a default (fully open) VM since lust itself requires
//! the string/table libraries. The runtime exits 0 even when a script
//! errors, so the lust summary line ("N passed and M failed.") is parsed
//! from the output instead of relying on exit codes.

mod common;

#[test]
fn lust_suite_runs_green() {
    let repo = std::path::Path::new(common::REPO_ROOT);

    let outcome = common::run_with_timeout(&["run", "tests/init.lua"], repo, 300);
    common::assert_not_hung(&outcome, "tests/init.lua");

    let (passes, errors) = common::parse_lust_summary(&outcome.stdout);

    assert!(
        passes > 0,
        "the Lua suite reported zero passes — it likely did not actually run:\n{}\n{}",
        outcome.stdout,
        outcome.stderr
    );
    assert_eq!(
        errors, 0,
        "the Lua suite had failures:\n{}\n{}",
        outcome.stdout, outcome.stderr
    );
}
