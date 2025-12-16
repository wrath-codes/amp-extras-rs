local n = require("nui-components")

local M = {}

---Open a command in a floating terminal
---@param cmd string The shell command to run
---@param opts table|nil Options { title = string, width = number, height = number, on_exit = fun() }
function M.float_term(cmd, opts)
  opts = opts or {}
  local title = opts.title or " Terminal "
  local width = opts.width or 80
  local height = opts.height or 24
  local on_exit_cb = opts.on_exit
  local autoscroll = opts.autoscroll ~= false -- default true

  local buf = vim.api.nvim_create_buf(false, true)

  local renderer = n.create_renderer({
    width = width,
    height = height,
    position = "50%",
  })

  local body = function()
    return n.buffer({
      id = "term_buf",
      buf = buf,
      autoscroll = autoscroll,
      border_label = {
        text = title,
        icon = "",
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

  vim.api.nvim_buf_call(buf, function()
    -- Clean terminal look
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"

    vim.fn.jobstart(cmd, {
      term = true,
      on_exit = function(job_id, exit_code, event)
        if on_exit_cb then
          pcall(on_exit_cb, exit_code)
        end
        vim.schedule(function()
          renderer:close()
          if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
          end
        end)
      end,
    })
  end)

  -- Map q and <Esc> to close in Normal mode
  -- (Terminal mode usually captures Esc, so user needs to exit term mode first with <C-\><C-n> or we map it in term mode too)
  local function close()
    renderer:close()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end

  vim.keymap.set("n", "q", close, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true })
  -- Optional: Map <Esc> in terminal mode if you want direct exit without needing C-\ C-n first,
  -- but this might interfere with TUI apps. For "amp -x", it's likely output only, so it's safe.
  vim.keymap.set(
    "t",
    "<Esc>",
    [[<C-\><C-n>:lua require('amp_extras.commands.session.ui')._close_buf() <CR>]],
    { buffer = buf, nowait = true }
  )
  -- We need to store the close function or handle it cleanly.
  -- Easier way: just feed keys or call close directly if we can access renderer from global scope, but we can't.
  -- So simpler: Just map <Esc> to exit terminal mode, then q works.
  -- Or use a hack to call close.

  vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { buffer = buf, nowait = true })
  vim.keymap.set("t", "q", [[<C-\><C-n>:q<CR>]], { buffer = buf, nowait = true }) -- simplistic approach

  -- Focus and insert
  vim.schedule(function()
    local component = renderer:get_component_by_id("term_buf")
    if component and component.winid and vim.api.nvim_win_is_valid(component.winid) then
      vim.api.nvim_set_current_win(component.winid)
      vim.cmd("startinsert")
    end
  end)
end

---Open a styled input box
---@param opts table { title = string, placeholder = string }
---@param on_submit fun(value: string)
function M.input_box(opts, on_submit)
  opts = opts or {}
  local title = opts.title or " Input "
  local placeholder = opts.placeholder or "Enter value..."

  local renderer = n.create_renderer({
    width = 60,
    height = 3,
  })

  local window_style = {
    highlight = {
      FloatBorder = "DiagnosticError",
      FloatTitle = "DiagnosticError",
    },
  }

  local body = n.text_input({
    id = "input_box",
    autofocus = true,
    border_label = {
      text = title,
      icon = "",
    },
    placeholder = placeholder,
    max_lines = 1,
    window = window_style,
    on_mount = function(component)
      if component.bufnr then
        vim.keymap.set({ "i", "n" }, "<CR>", function()
          local val = component:get_current_value()
          renderer:close()
          if val and vim.trim(val) ~= "" then
            on_submit(val)
          end
        end, { buffer = component.bufnr })

        vim.keymap.set("n", "<Esc>", function()
          renderer:close()
        end, { buffer = component.bufnr })
      end
    end,
  })

  renderer:render(body)
end

return M
