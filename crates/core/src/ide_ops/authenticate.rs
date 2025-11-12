//! Token authentication operation

use serde_json::{json, Value};

use crate::errors::Result;

/// Handle authenticate request
///
/// Simple authentication handshake for IDE protocol.
/// In the amp.nvim implementation, this just acknowledges the connection.
///
/// Request:
/// ```json
/// {}
/// ```
///
/// Response:
/// ```json
/// { "authenticated": true }
/// ```
pub fn authenticate(_params: Value) -> Result<Value> {
    Ok(json!({
        "authenticated": true
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_authenticate_success() {
        let result = authenticate(json!({})).unwrap();

        assert_eq!(result["authenticated"], json!(true));
    }

    #[test]
    fn test_authenticate_with_params() {
        // authenticate ignores params for now
        let result = authenticate(json!({"token": "abc123"})).unwrap();

        assert_eq!(result["authenticated"], json!(true));
    }
}
