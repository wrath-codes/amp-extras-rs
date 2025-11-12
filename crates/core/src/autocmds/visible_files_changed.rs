//! Visible files change notifications
//!
//! Handles BufEnter and WinEnter events, sending visibleFilesDidChange
//! notifications when the set of visible files changes.
//!
//! Implements 10ms debouncing to avoid excessive notifications during
//! rapid window switching.

use std::cell::RefCell;
use std::sync::Arc;
use std::time::Duration;

use nvim_oxi::api::{self, opts::CreateAutocmdOpts};
use nvim_oxi::api::types::AutocmdCallbackArgs;
use nvim_oxi::libuv::TimerHandle;

use crate::errors::Result;
use crate::notifications;
use crate::nvim::{path, window};
use crate::server::Hub;

/// Debounce delay for visible files notifications (10ms)
pub(super) const DEBOUNCE_MS: u64 = 10;

/// Register BufEnter and WinEnter autocommands
///
/// # Arguments
/// * `group_id` - Autocommand group ID
/// * `hub` - WebSocket Hub for broadcasting
pub(super) fn register(group_id: u32, hub: Arc<Hub>) -> Result<()> {
    // Storage for debounce timer (RefCell for interior mutability)
    let debounce_timer = RefCell::new(None::<TimerHandle>);

    let opts = CreateAutocmdOpts::builder()
        .group(group_id)
        .desc("Send visibleFilesDidChange notification on buffer/window changes (debounced)")
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

    api::create_autocmd(["BufEnter", "WinEnter"], &opts)
        .map_err(|e| crate::errors::AmpError::Other(format!("Failed to create buffer autocmd: {}", e)))?;

    Ok(())
}

/// Handle visible files changed event
///
/// Gets list of all visible buffers, sends notification to clients.
pub(crate) fn handle_event(hub: &Hub) -> Result<()> {
    // Get all visible buffer paths
    let paths = window::get_visible_buffers()?;

    // Convert to file:// URIs
    let uris: Vec<String> = paths
        .iter()
        .map(|p| path::to_uri(p))
        .collect::<Result<Vec<String>>>()?;

    notifications::send_visible_files_changed(hub, uris)?;

    Ok(())
}