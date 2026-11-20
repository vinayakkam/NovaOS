//! NovaOS WinLayer (stub).
//!
//! Plan: registered as the handler for application/x-ms-dos-executable and
//! application/x-msi. Double-clicking an .exe/.msi runs it through Wine in a per-app prefix
//! (~/.local/share/novaos/wine/<app>), shows a friendly progress dialog, and creates a menu
//! entry after install. For now it builds the Wine command and runs it (or prints it with
//! --dry-run).

use std::ffi::OsString;
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode};

#[derive(Debug, PartialEq)]
enum Kind {
    Exe,
    Msi,
}

fn kind_of(path: &Path) -> Option<Kind> {
    match path.extension()?.to_str()?.to_ascii_lowercase().as_str() {
        "exe" => Some(Kind::Exe),
        "msi" => Some(Kind::Msi),
        _ => None,
    }
}

fn wine_command(path: &Path, prefix: &Path) -> Command {
    let mut cmd = Command::new("wine");
    cmd.env("WINEPREFIX", prefix);
    match kind_of(path) {
        Some(Kind::Msi) => {
            cmd.arg("msiexec").arg("/i").arg(path);
        }
        _ => {
            cmd.arg(path);
        }
    }
    cmd
}

fn default_prefix() -> PathBuf {
    let base = std::env::var_os("XDG_DATA_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".local/share")))
        .unwrap_or_else(|| PathBuf::from("."));
    base.join("novaos/wine/default")
}

fn main() -> ExitCode {
    let args: Vec<OsString> = std::env::args_os().skip(1).collect();
    let dry_run = args.iter().any(|a| a == "--dry-run");
    let Some(file) = args.iter().find(|a| *a != "--dry-run") else {
        eprintln!("usage: novaos-winlayer [--dry-run] <program.exe|installer.msi>");
        return ExitCode::from(2);
    };
    let path = Path::new(file);
    if kind_of(path).is_none() {
        eprintln!("novaos-winlayer: {} is not an .exe or .msi", path.display());
        return ExitCode::from(2);
    }

    let cmd = wine_command(path, &default_prefix());
    if dry_run {
        println!("{:?}", cmd);
        return ExitCode::SUCCESS;
    }
    let mut cmd = cmd;
    match cmd.status() {
        Ok(s) if s.success() => ExitCode::SUCCESS,
        Ok(s) => {
            eprintln!("novaos-winlayer: wine exited with {s}");
            ExitCode::FAILURE
        }
        Err(e) => {
            eprintln!("novaos-winlayer: could not start wine: {e}");
            ExitCode::FAILURE
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn detects_kinds() {
        assert_eq!(kind_of(Path::new("Setup.EXE")), Some(Kind::Exe));
        assert_eq!(kind_of(Path::new("app.msi")), Some(Kind::Msi));
        assert_eq!(kind_of(Path::new("readme.txt")), None);
    }

    #[test]
    fn msi_uses_msiexec() {
        let cmd = wine_command(Path::new("app.msi"), Path::new("/tmp/p"));
        let args: Vec<_> = cmd.get_args().collect();
        assert_eq!(args[0], "msiexec");
        assert_eq!(args[1], "/i");
    }
}
