//! The fixture's shared library.

/// The line `tool --version` prints for a binary called `name` at `version`.
#[must_use]
pub fn version_line(name: &str, version: &str) -> String {
    format!("{name} {version}")
}

#[cfg(test)]
mod tests {
    use super::version_line;

    #[test]
    fn joins_the_name_and_the_version() {
        assert_eq!(version_line("tool", "1.2.3"), "tool 1.2.3");
    }
}
