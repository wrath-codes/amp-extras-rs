-- FFI interface to Rust core library
local M = {}

local binary = require("amp_extras.binary")

-- The loaded FFI module (lazy-loaded)
local ffi = nil
local load_error = nil

--- Ensure the FFI module is loaded
---@return table|nil module, string|nil error
local function ensure_loaded()
  if ffi then
    return ffi
  end

  if load_error then
    return nil, load_error
  end

  local mod, err = binary.load()
  if mod then
    ffi = mod
    return ffi
  else
    load_error = err
    return nil, err
  end
end

-- ============================================================================
-- Command Interface
-- ============================================================================

--- Call a command through the FFI
---@param command string Command name (e.g., "ping", "send_selection")
---@param args table Command arguments
---@return table Result or error object
function M.call(command, args)
  local mod, err = ensure_loaded()
  if not mod then
    return { error = true, message = "FFI not loaded: " .. (err or "unknown") }
  end

  args = args or {}
  local result = mod.call(command, args)

  -- Check if result is an error
  if result.error then
    return { nil, result.message }
  end

  return result
end

-- ============================================================================
-- Autocomplete Interface
-- ============================================================================

--- Get autocomplete suggestions
---@param kind string Type of completion ("thread", "prompt", "file")
---@param prefix string User-typed prefix
---@return string[] Completion items
function M.autocomplete(kind, prefix)
  local mod, err = ensure_loaded()
  if not mod then
    vim.notify("amp-extras: FFI not loaded: " .. (err or "unknown"), vim.log.levels.WARN)
    return {}
  end

  return mod.autocomplete(kind, prefix)
end

-- ============================================================================
-- Plugin Setup Interface
-- ============================================================================

--- Setup the plugin with configuration
---
---@param config table Configuration options
---@return table result Success status or error object
function M.setup(config)
  local mod, err = ensure_loaded()
  if not mod then
    return { error = true, message = "FFI not loaded: " .. (err or "unknown") }
  end

  return mod.setup(config or {})
end

--- Check if the FFI is available
---@return boolean
function M.is_available()
  local mod = ensure_loaded()
  return mod ~= nil
end

--- Get the load error if any
---@return string|nil
function M.get_error()
  ensure_loaded()
  return load_error
end

return M
