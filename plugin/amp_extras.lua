-- amp-extras: Neovim user commands
-- Plugin entrypoint that registers commands

local commands = require("amp_extras.commands")

-- ============================================================================
-- Visual Mode Commands
-- ============================================================================

vim.api.nvim_create_user_command("AmpSendSelection", function(opts)
  commands.send_selection(opts.line1, opts.line2)
end, {
  range = true,
  desc = "Send selected text to Amp prompt",
})

vim.api.nvim_create_user_command("AmpSendSelectionRef", function(opts)
  commands.send_selection_ref(opts.line1, opts.line2)
end, {
  range = true,
  desc = "Send file reference with line range to Amp prompt (@file.rs#L10-L20)",
})

-- ============================================================================
-- Normal Mode Commands
-- ============================================================================

vim.api.nvim_create_user_command("AmpSendBuffer", function()
  commands.send_buffer()
end, {
  desc = "Send entire buffer content to Amp prompt",
})

vim.api.nvim_create_user_command("AmpSendFileRef", function()
  commands.send_file_ref()
end, {
  desc = "Send file reference to Amp prompt (@file.rs)",
})

vim.api.nvim_create_user_command("AmpSendLineRef", function()
  commands.send_line_ref()
end, {
  desc = "Send current line reference to Amp prompt (@file.rs#L10)",
})

-- ============================================================================
-- Server Commands
-- ============================================================================

local amp = require("amp_extras")

vim.api.nvim_create_user_command("AmpServerStart", function()
  local result, err = amp.server_start()
  if err then
    vim.notify("Failed to start Amp server: " .. err, vim.log.levels.ERROR)
    return
  end
  vim.notify(
    string.format("Amp server started on port %d", result.port),
    vim.log.levels.INFO
  )
end, {
  desc = "Start the Amp WebSocket server",
})

vim.api.nvim_create_user_command("AmpServerStop", function()
  if amp.server_stop() then
    vim.notify("Amp server stopped", vim.log.levels.INFO)
  else
    vim.notify("Failed to stop Amp server", vim.log.levels.ERROR)
  end
end, {
  desc = "Stop the Amp WebSocket server",
})

vim.api.nvim_create_user_command("AmpServerStatus", function()
  if amp.server_is_running() then
    vim.notify("Amp server is running", vim.log.levels.INFO)
  else
    vim.notify("Amp server is not running", vim.log.levels.INFO)
  end
end, {
  desc = "Check Amp WebSocket server status",
})
