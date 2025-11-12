//! Health check operation

use serde_json::{json, Value};

use crate::errors::Result;

/// Handle ping request
///
/// Health check endpoint for IDE protocol.
/// Supports two modes:
/// 1. Standard: Returns pong + timestamp
/// 2. Echo mode: Returns message parameter (amp.nvim format)
///
/// Request (standard):
/// ```json
/// {}
/// ```
///
/// Response (standard):
/// ```json
/// {
///   "pong": true,
///   "ts": "2024-01-01T12:00:00Z"
/// }
/// ```
///
/// Request (echo):
/// ```json
/// { "message": "hello" }
/// ```
///
/// Response (echo):
/// ```json
/// { "message": "hello" }
/// ```
pub fn ping(params: Value) -> Result<Value> {
    // Check if there's a message to echo (amp.nvim format)
    if let Some(message) = params.get("message") {
        Ok(json!({
            "message": message
        }))
    } else {
        // Standard ping response
        Ok(json!({
            "pong": true,
            "ts": chrono::Utc::now().to_rfc3339()
        }))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ping_returns_pong() {
        let result = ping(json!({})).unwrap();

        assert_eq!(result["pong"], json!(true));
        assert!(result.get("ts").is_some());
    }

    #[test]
    fn test_ping_with_message() {
        // amp.nvim format - echo message
        let result = ping(json!({"message": "hello"})).unwrap();

        assert_eq!(result["message"], json!("hello"));
    }

    #[test]
    fn test_ping_without_message() {
        // Standard format - return pong
        let result = ping(json!({"other": "data"})).unwrap();

        assert_eq!(result["pong"], json!(true));
        assert!(result.get("ts").is_some());
    }

    #[test]
    fn test_ping_timestamp_format() {
        let result = ping(json!({})).unwrap();
        let ts = result["ts"].as_str().unwrap();

        // Should be valid RFC3339 timestamp
        assert!(chrono::DateTime::parse_from_rfc3339(ts).is_ok());
    }
}
