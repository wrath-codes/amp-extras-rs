//! Selection/cursor position change notifications
//!
//! Handles CursorMoved and CursorMovedI events, sending selectionDidChange
//! notifications when cursor position or visual selection changes.
//!
//! Implements 10ms debouncing to avoid excessive notifications during
//! rapid cursor movement.

use std::cell::RefCell;
use std::sync::Arc;
use std::time::Duration;

use nvim_oxi::api::{self, opts::CreateAutocmdOpts};
use nvim_oxi::api::types::AutocmdCallbackArgs;
use nvim_oxi::libuv::TimerHandle;

use crate::errors::Result;
use crate::notifications;
use crate::nvim::{cursor, path, selection};
use crate::server::Hub;

/// Debounce delay for cursor movement notifications (10ms)
pub(super) const DEBOUNCE_MS: u64 = 10;

/// Register CursorMoved and CursorMovedI autocommands
///
/// # Arguments
/// * `group_id` - Autocommand group ID
/// * `hub` - WebSocket Hub for broadcasting
pub(super) fn register(group_id: u32, hub: Arc<Hub>) -> Result<()> {
    // Storage for debounce timer (RefCell for interior mutability)
    let debounce_timer = RefCell::new(None::<TimerHandle>);

    let opts = CreateAutocmdOpts::builder()
        .group(group_id)
        .desc("Send selectionDidChange notification on cursor move (debounced)")
        .callback(move |_args: AutocmdCallbackArgs| {
            // Cancel previous timer if exists
            if let Some(mut timer) = debounce_timer.borrow_mut().take() {
                let _ = timer.stop();
            }

            // Clone hub for timer callback
            let hub_clone = hub.clone();

            // Start new debounced timer
            match TimerHandle::once(Duration::from_millis(DEBOUNCE_MS), move || {
                // Execute after debounce delay
                if let Err(e) = handle_event(&hub_clone) {
                    // Errors are silently ignored to avoid ghost text
                    let _ = e;
                }
                Ok::<_, nvim_oxi::Error>(())
            }) {
                Ok(timer) => {
                    // Store timer to keep it alive
                    *debounce_timer.borrow_mut() = Some(timer);
                }
                Err(_e) => {
                    // Timer creation failed - skip this event
                }
            }

            // Keep autocommand active (return false)
            Ok::<_, nvim_oxi::Error>(false)
        })
        .build();

    api::create_autocmd(["CursorMoved", "CursorMovedI"], &opts)
        .map_err(|e| crate::errors::AmpError::Other(format!("Failed to create cursor autocmd: {}", e)))?;

    Ok(())
}

/// Handle cursor/selection change event
///
/// Gets current cursor position and selection, sends notification to clients.
pub(crate) fn handle_event(hub: &Hub) -> Result<()> {
    // Get current buffer and file path
    let buf = api::get_current_buf();
    let buf_path = buf.get_name()
        .map_err(|e| crate::errors::AmpError::Other(format!("Failed to get buffer name: {}", e)))?;

    // Convert to file:// URI
    let uri = if buf_path.is_absolute() {
        path::to_uri(&buf_path)?
    } else {
        // Handle unnamed/scratch buffers - skip notification
        return Ok(());
    };

    // Check if in visual mode
    let mode = selection::get_mode()?;

    let (start_line, start_char, end_line, end_char, content) = if mode.mode.is_visual() {
        // Visual mode - get actual selection
        match selection::get_visual_selection(&buf, &mode.mode) {
            Ok(Some((s_line, s_col, e_line, e_col, text))) => {
                // Marks are (1,0)-indexed, convert to 0-indexed
                let start_line = (s_line.saturating_sub(1)) as usize;
                let start_char = s_col as usize;
                let end_line = (e_line.saturating_sub(1)) as usize;
                let end_char = e_col as usize;
                (start_line, start_char, end_line, end_char, text)
            }
            Ok(None) | Err(_) => {
                // Fallback to cursor position if marks fail
                cursor::get_position_as_range()?
            }
        }
    } else {
        // Normal mode - send cursor position as zero-width selection
        cursor::get_position_as_range()?
    };

    notifications::send_selection_changed(
        hub,
        &uri,
        start_line,
        start_char,
        end_line,
        end_char,
        &content,
    )?;

    Ok(())
}

