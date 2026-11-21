//! TwilightOS Quick Look (stub).
//!
//! Plan: a Dolphin service menu / KIO plugin calls `twilightos-quicklook <path>` when the user
//! presses Space; this opens a borderless preview window (images, PDFs, text, video) that
//! closes on Space/Esc. For now it only classifies the file so the integration can be wired up.

use std::path::Path;
use std::process::ExitCode;

#[derive(Debug, PartialEq)]
enum PreviewKind {
    Image,
    Pdf,
    Text,
    Video,
    Audio,
    Directory,
    Unsupported,
}

fn classify(path: &Path) -> PreviewKind {
    if path.is_dir() {
        return PreviewKind::Directory;
    }
    let ext = path
        .extension()
        .and_then(|e| e.to_str())
        .map(|e| e.to_ascii_lowercase())
        .unwrap_or_default();
    match ext.as_str() {
        "png" | "jpg" | "jpeg" | "gif" | "webp" | "bmp" | "svg" | "avif" => PreviewKind::Image,
        "pdf" => PreviewKind::Pdf,
        "txt" | "md" | "rs" | "toml" | "json" | "sh" | "py" | "log" | "conf" | "ini" => PreviewKind::Text,
        "mp4" | "mkv" | "webm" | "mov" => PreviewKind::Video,
        "mp3" | "flac" | "ogg" | "wav" | "opus" => PreviewKind::Audio,
        _ => PreviewKind::Unsupported,
    }
}

fn main() -> ExitCode {
    let Some(arg) = std::env::args_os().nth(1) else {
        eprintln!("usage: twilightos-quicklook <file>");
        return ExitCode::from(2);
    };
    let path = Path::new(&arg);
    if !path.exists() {
        eprintln!("twilightos-quicklook: {} does not exist", path.display());
        return ExitCode::FAILURE;
    }
    let kind = classify(path);
    let size = std::fs::metadata(path).map(|m| m.len()).unwrap_or(0);
    println!("{}: {:?} ({} bytes) - preview window not implemented yet", path.display(), kind, size);
    ExitCode::SUCCESS
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn classifies_by_extension() {
        assert_eq!(classify(Path::new("photo.JPG")), PreviewKind::Image);
        assert_eq!(classify(Path::new("doc.pdf")), PreviewKind::Pdf);
        assert_eq!(classify(Path::new("archive.zip")), PreviewKind::Unsupported);
    }
}
