local M = {}

--- Get a snapshot of the current Amp status
--- @return table Status snapshot with running, client_count, and port
local function get_amp_status()
  local ok, amp = pcall(require, "amp")
  if not ok or not amp.state then
    return {
      running = false,
      client_count = 0,
      port = nil,
    }
  end

  local running = amp.state.server ~= nil
  local port = amp.state.port or 0

  local client_count = 0
  local ok_server, server = pcall(require, "amp.server.init")
  if ok_server and server.get_status then
    local server_status = server.get_status()
    client_count = server_status.client_count or 0
  elseif amp.state.connected then
    -- Fallback: at least one client, but count unknown
    client_count = 1
  end

  return {
    running = running,
    client_count = client_count,
    port = port,
  }
end

--- Setup lualine integration
--- @param config table|nil Configuration options
function M.setup(config)
  config = config or {}

  -- Detect colors from current colorscheme or fall back to defaults
  local colors = M.get_colors()

  -- Define highlight groups
  vim.api.nvim_set_hl(0, "AmpRunning", { fg = colors.running.icon, bg = colors.transparent })
  vim.api.nvim_set_hl(0, "AmpPort", { fg = colors.running.port, bg = colors.transparent })
  vim.api.nvim_set_hl(0, "AmpConnected", { fg = colors.connected.icon, bg = colors.transparent })
  vim.api.nvim_set_hl(0, "AmpClients", { fg = colors.connected.clients, bg = colors.transparent })
  vim.api.nvim_set_hl(0, "AmpStopped", { fg = colors.stopped.icon, bg = colors.transparent })

  -- Auto-refresh lualine when Amp status changes via polling
  -- Always start the poller, even if Amp isn't loaded yet (it might be lazy-loaded later)
  local function refresh()
    vim.schedule(function()
      local ok_lualine, lualine = pcall(require, "lualine")
      if ok_lualine then
        lualine.refresh()
      end
    end)
  end

  -- Avoid multiple timers if setup() is called more than once
  if M._timer then
    M._timer:stop()
    M._timer:close()
    M._timer = nil
  end

  local last_status = get_amp_status()
  local timer = vim.loop.new_timer()
  M._timer = timer

  timer:start(
    1000, -- initial wait
    1000, -- repeat interval
    vim.schedule_wrap(function()
      local status = get_amp_status()
      -- Deep compare status to check for changes
      if
        status.running ~= last_status.running
        or status.client_count ~= last_status.client_count
        or status.port ~= last_status.port
      then
        -- Force redraw on status change
        vim.cmd("redrawstatus")
        last_status = status
        refresh()
      end
    end)
  )

  -- Clean up timer on exit
  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      if M._timer then
        M._timer:stop()
        M._timer:close()
        M._timer = nil
      end
    end,
  })

  -- Return the component function for lualine
  return M.component
end

--- Get colors based on current theme or defaults
function M.get_colors()
  -- Try to get colors from current scheme
  local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
  local string_hl = vim.api.nvim_get_hl(0, { name = "String" })
  local function_hl = vim.api.nvim_get_hl(0, { name = "Function" })
  local comment_hl = vim.api.nvim_get_hl(0, { name = "Comment" })
  local constant_hl = vim.api.nvim_get_hl(0, { name = "Constant" })
  local special_hl = vim.api.nvim_get_hl(0, { name = "Special" })

  -- Helper to convert integer color to hex string
  local function to_hex(int_color)
    if not int_color then
      return nil
    end
    return string.format("#%06x", int_color)
  end

  -- Default fallback colors (based on Catppuccin Mocha as reference)
  local defaults = {
    mauve = "#cba6f7",
    teal = "#94e2d5",
    green = "#a6e3a1",
    peach = "#fab387",
    overlay0 = "#6c7086",
    mantle = "#181825",
  }

  -- Dynamic colors extracted from current theme
  local dynamic = {
    purple = to_hex(function_hl.fg) or defaults.mauve,
    cyan = to_hex(special_hl.fg) or defaults.teal,
    green = to_hex(string_hl.fg) or defaults.green,
    orange = to_hex(constant_hl.fg) or defaults.peach,
    gray = to_hex(comment_hl.fg) or defaults.overlay0,
    bg = to_hex(normal.bg) or defaults.mantle,
  }

  return {
    running = {
      icon = dynamic.purple, -- Function color (usually purple/blue)
      port = dynamic.cyan, -- Special color (usually cyan/orange)
    },
    connected = {
      icon = dynamic.green, -- String color (usually green)
      clients = dynamic.orange, -- Constant color (usually orange/yellow)
    },
    stopped = {
      icon = dynamic.gray, -- Comment color (usually gray)
      text = dynamic.bg,
    },
    transparent = "NONE",
  }
end

--- The actual lualine component
function M.component()
  -- Ensure polling is active (handles case where setup() wasn't called)
  if not M._timer then
    M.setup()
  end

  local status = get_amp_status()

  if not status.running then
    -- Server stopped - show dim indicator
    return string.format("%%#AmpStopped# ● Amp")
  end

  if status.client_count > 0 then
    -- Connected - show active indicator with client count
    return string.format(
      "%%#AmpConnected#● %%#AmpPort#Amp:%d %%#AmpClients#[%d]",
      status.port,
      status.client_count
    )
  else
    -- Running but no clients - show waiting indicator
    return string.format("%%#AmpRunning#○ %%#AmpPort#Amp:%d", status.port)
  end
end

return M
