-- Command wrappers for Amp integration
-- Trivial wrappers - all logic is in Rust

local M = {}

local amp = require("amp_extras")

-- ============================================================================
-- Visual Mode Commands (selection-based)
-- ============================================================================

--- Send selected text to Amp prompt
---@param start_line number Start line (1-indexed)
---@param end_line number End line (1-indexed)
---@return boolean success
---@return string|nil error
function M.send_selection(start_line, end_line)
  local result, err = amp.call("send_selection", {
    start_line = start_line,
    end_line = end_line,
  })

  if err then
    vim.notify("Failed to send selection: " .. err, vim.log.levels.ERROR)
    return false, err
  end

  return true
end

--- Send file reference with line range to Amp prompt
---@param start_line number Start line (1-indexed)
---@param end_line number End line (1-indexed)
---@return boolean success
---@return string|nil error
function M.send_selection_ref(start_line, end_line)
  local result, err = amp.call("send_selection_ref", {
    start_line = start_line,
    end_line = end_line,
  })

  if err then
    vim.notify("Failed to send selection reference: " .. err, vim.log.levels.ERROR)
    return false, err
  end

  vim.notify("Sent: " .. result.reference, vim.log.levels.INFO)
  return true
end

-- ============================================================================
-- Normal Mode Commands (buffer/file-based)
-- ============================================================================

--- Send entire buffer content to Amp prompt
---@return boolean success
---@return string|nil error
function M.send_buffer()
  local result, err = amp.call("send_buffer", {})

  if err then
    vim.notify("Failed to send buffer: " .. err, vim.log.levels.ERROR)
    return false, err
  end

  return true
end

--- Send file reference to Amp prompt
---@return boolean success
---@return string|nil error
function M.send_file_ref()
  local result, err = amp.call("send_file_ref", {})

  if err then
    vim.notify("Failed to send file reference: " .. err, vim.log.levels.ERROR)
    return false, err
  end

  vim.notify("Sent: " .. result.reference, vim.log.levels.INFO)
  return true
end

--- Send current line reference to Amp prompt
---@return boolean success
---@return string|nil error
function M.send_line_ref()
  local result, err = amp.call("send_line_ref", {})

  if err then
    vim.notify("Failed to send line reference: " .. err, vim.log.levels.ERROR)
    return false, err
  end

  vim.notify("Sent: " .. result.reference, vim.log.levels.INFO)
  return true
end

return M
