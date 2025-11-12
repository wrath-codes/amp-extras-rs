//! Path and URI conversion utilities
//!
//! Provides functions for converting between file paths and URIs,
//! and for getting workspace-relative paths.

use nvim_oxi::api;
use std::path::Path;

use crate::errors::{AmpError, Result};

/// Convert a file path to a file:// URI
///
/// # Arguments
/// * `path` - File path to convert
///
/// # Returns
/// A file:// URI string (e.g., "file:///home/user/file.txt")
///
/// # Example
/// ```rust,ignore
/// let uri = path::to_uri(Path::new("/tmp/test.txt"));
/// assert_eq!(uri, "file:///tmp/test.txt");
/// ```
pub(crate) fn to_uri(path: &Path) -> String {
    format!("file://{}", path.display())
}

/// Convert a file:// URI to a file path
///
/// # Arguments
/// * `uri` - file:// URI string
///
/// # Returns
/// - `Some(path)` - Successfully parsed path
/// - `None` - Invalid URI format
///
/// # Example
/// ```rust,ignore
/// let path = path::from_uri("file:///tmp/test.txt");
/// assert_eq!(path, Some(PathBuf::from("/tmp/test.txt")));
/// ```
pub(crate) fn from_uri(uri: &str) -> Option<std::path::PathBuf> {
    uri.strip_prefix("file://")
        .map(std::path::PathBuf::from)
}

/// Convert an absolute path to a workspace-relative path
///
/// Uses Neovim's `fnamemodify(path, ':.')` to get the path relative to the
/// current working directory. This is used for creating file references like
/// `@src/main.rs` instead of `@/home/user/project/src/main.rs`.
///
/// # Arguments
/// * `path` - Absolute file path to convert
///
/// # Returns
/// Workspace-relative path as a String
///
/// # Errors
/// Returns error if Neovim API call fails
///
/// # Example
/// ```rust,ignore
/// let relative = path::to_relative(Path::new("/home/user/project/src/main.rs"))?;
/// // Returns: "src/main.rs" (if cwd is /home/user/project)
/// ```
pub(crate) fn to_relative(path: &Path) -> Result<String> {
    // Convert path to string
    let path_str = path
        .to_str()
        .ok_or_else(|| AmpError::Other("Invalid path encoding".into()))?;

    // Check if path is empty
    if path_str.is_empty() {
        return Err(AmpError::Other("Empty path provided".into()));
    }

    // Use fnamemodify(path, ':.') to get relative path
    let result: std::result::Result<nvim_oxi::Object, _> =
        api::call_function("fnamemodify", (path_str, ":."));

    if let Ok(obj) = result {
        use nvim_oxi::conversion::FromObject;
        if let Ok(relative) = <String as FromObject>::from_object(obj) {
            // Filter out "v:null" or other invalid values
            if !relative.is_empty() && !relative.starts_with("v:") {
                return Ok(relative);
            }
        }
    }

    // Fallback: return path as-is (if it's absolute)
    if path.is_absolute() {
        Ok(path_str.to_string())
    } else {
        Err(AmpError::Other(format!("Failed to get relative path for: {}", path_str)))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    #[test]
    fn test_to_uri() {
        let path = Path::new("/tmp/test.txt");
        let uri = to_uri(path);
        assert_eq!(uri, "file:///tmp/test.txt");
    }

    #[test]
    fn test_to_uri_with_spaces() {
        let path = Path::new("/tmp/my file.txt");
        let uri = to_uri(path);
        assert_eq!(uri, "file:///tmp/my file.txt");
    }

    #[test]
    fn test_from_uri() {
        let uri = "file:///tmp/test.txt";
        let path = from_uri(uri);
        assert_eq!(path, Some(PathBuf::from("/tmp/test.txt")));
    }

    #[test]
    fn test_from_uri_invalid() {
        let uri = "http://example.com/file.txt";
        let path = from_uri(uri);
        assert_eq!(path, None);
    }

    #[test]
    fn test_roundtrip() {
        let original = Path::new("/home/user/project/src/main.rs");
        let uri = to_uri(original);
        let back = from_uri(&uri);
        assert_eq!(back, Some(original.to_path_buf()));
    }

    #[test]
    #[ignore = "Requires Neovim context"]
    fn test_to_relative() {
        // This test requires actual Neovim context
        // Run with: just test-integration
        let path = Path::new("/home/user/project/src/main.rs");
        let result = to_relative(path);
        // Would return "src/main.rs" if cwd is /home/user/project
        assert!(result.is_ok());
    }
}
