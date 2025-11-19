local M = {}

M.command = function()
  local n = require("nui-components")

  -- Create a buffer for the terminal
  local buf = vim.api.nvim_create_buf(false, true)

  local renderer = n.create_renderer({
    width = 80,
    height = 24,
    position = "50%",
  })

  local body = function()
    return n.buffer({
      id = "login_term", -- Add ID to access component later
      buf = buf,
      autoscroll = true,
      border_label = {
        text = " Amp Login ",
        icon = "󰶼",
        edge = "top",
        align = "center",
      },
      window = {
        relative = "editor",
        focusable = true,
        highlight = {
          Normal = "Normal",
          FloatBorder = "DiagnosticError",
          FloatTitle = "DiagnosticError",
          NormalFloat = "NormalFloat",
        },
      },
    })
  end

  renderer:render(body)

  -- Run the command in the buffer
  -- We wrap it to wait for a keypress so the user can see the result
  local shell_cmd = "amp login; echo ''; echo 'Press any key to close...'; read -n 1"

  vim.api.nvim_buf_call(buf, function()
    -- Set some terminal options for better UX
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"

    vim.fn.termopen(shell_cmd, {
      on_exit = function()
        vim.schedule(function()
          renderer:close()
          -- Ensure we delete the buffer to clean up
          if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
          end
        end)
      end,
    })
  end)

  -- Ensure we are in insert mode and focused on the terminal
  vim.schedule(function()
    local component = renderer:get_component_by_id("login_term")
    if component and component.winid and vim.api.nvim_win_is_valid(component.winid) then
      vim.api.nvim_set_current_win(component.winid)
      vim.cmd("startinsert")
    end
  end)
end

return M
