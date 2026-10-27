//! The fixture's CLI: `tool --version` prints its name and version.

use std::env;

fn main() {
    if env::args().nth(1).as_deref() == Some("--version") {
        println!(
            "{}",
            shared::version_line(env!("CARGO_PKG_NAME"), env!("CARGO_PKG_VERSION"))
        );
    } else {
        eprintln!("usage: tool --version");
        std::process::exit(2);
    }
}

#[cfg(test)]
mod tests {
    use std::process::Command;

    /// Runs only where the dev shell's git is on `PATH`, as forge's `test`
    /// check puts it there.
    #[test]
    fn git_from_the_dev_shell_runs() {
        let output = Command::new("git")
            .arg("--version")
            .output()
            .expect("git is on PATH");

        assert!(output.status.success());
        assert!(String::from_utf8_lossy(&output.stdout).starts_with("git version"));
    }
}
