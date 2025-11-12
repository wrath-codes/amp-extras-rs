//! Path and URI conversion utilities
//!
//! Provides functions for converting between file paths and URIs.

use std::path::Path;

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
}
