//! Buffer content and metadata utilities
//!
//! Provides functions for working with Neovim buffers.

use std::path::{Path, PathBuf};

use nvim_oxi::api::{self, Buffer};

use crate::errors::Result;

/// Get current buffer's file path
///
/// Returns None if the buffer is unnamed or a scratch buffer.
///
/// # Returns
/// - `Ok(Some(path))` - Absolute path to the buffer's file
/// - `Ok(None)` - Buffer has no associated file (unnamed/scratch)
/// - `Err(_)` - Error getting buffer name
pub(crate) fn current_path() -> Result<Option<PathBuf>> {
    let buf = api::get_current_buf();
    let path = buf
        .get_name()
        .map_err(|e| crate::errors::AmpError::Other(format!("Failed to get buffer name: {}", e)))?;

    if path.is_absolute() {
        Ok(Some(path))
    } else {
        Ok(None)
    }
}

/// Find a buffer by its file path
///
/// Searches all loaded buffers for one matching the given path.
///
/// # Arguments
/// * `path` - Absolute file path to search for
///
/// # Returns
/// - `Ok(Some(buffer))` - Buffer was found
/// - `Ok(None)` - No buffer with that path exists
pub(crate) fn find_by_path(path: &Path) -> Result<Option<Buffer>> {
    for buf in api::list_bufs() {
        if !buf.is_loaded() {
            continue;
        }

        if let Ok(buf_path) = buf.get_name() {
            if buf_path == path {
                return Ok(Some(buf));
            }
        }
    }

    Ok(None)
}

/// Get the content of a specific line from a file path
///
/// Returns empty string if the file is not loaded in a buffer or line doesn't exist.
///
/// # Arguments
/// * `path` - Path to the file
/// * `line_num` - Line number (0-indexed)
///
/// # Returns
/// Line content as a String, or empty string if not found
pub(crate) fn get_line_content(path: &Path, line_num: usize) -> String {
    // Find buffer by path
    let Some(buf) = find_by_path(path).ok().flatten() else {
        return String::new();
    };

    // Get the specific line (0-indexed)
    if let Ok(lines) = buf.get_lines(line_num..line_num + 1, false) {
        if let Some(line) = lines.into_iter().next() {
            return line.to_string_lossy().into();
        }
    }

    String::new()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_find_by_path_returns_none_when_not_found() {
        // In test environment without Neovim, list_bufs returns empty
        let result = find_by_path(Path::new("/nonexistent/file.txt"));
        assert!(result.is_ok());
        assert!(result.unwrap().is_none());
    }

    #[test]
    fn test_get_line_content_returns_empty_when_not_found() {
        let content = get_line_content(Path::new("/nonexistent/file.txt"), 0);
        assert_eq!(content, "");
    }
}
