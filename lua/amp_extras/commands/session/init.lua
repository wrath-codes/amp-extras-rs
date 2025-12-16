local ui = require("amp_extras.commands.session.ui")
local api = require("amp_extras.commands.dashx.api")

local M = {}

---Start a new interactive Amp session (Split)
function M.start()
  -- Create a new buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Split vertically
  vim.cmd("vsplit")

  -- Switch to the new buffer in the split
  vim.api.nvim_set_current_buf(buf)

  -- Configure buffer for terminal
  vim.opt_local.number = false
  vim.opt_local.relativenumber = false
  vim.opt_local.signcolumn = "no"

  -- Run amp --ide
  vim.fn.jobstart("amp --ide", {
    term = true,
    on_exit = function(job_id, exit_code, event)
      -- Close the buffer on exit if successful
      if exit_code == 0 then
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      else
        vim.notify("Amp session exited with code " .. tostring(exit_code), vim.log.levels.WARN)
      end
    end,
  })

  vim.cmd("startinsert")
end

---Execute a prompt in a floating session
function M.execute()
  ui.input_box({
    title = " Amp Execute ",
    placeholder = "Enter prompt...",
  }, function(input)
    -- Save as quick prompt
    local title = string.sub(input, 1, 30)
    if #input > 30 then
      title = title .. "..."
    end
    pcall(api.create_prompt, title, "No Description", input, { "quick_prompt" })

    M._run_execute(input)
  end)
end

---Start session with initial message (Split)
function M.start_with_message()
  ui.input_box({
    title = " Amp Session Message ",
    placeholder = "Enter initial message...",
  }, function(input)
    M._run_start_with_message(input)
  end)
end

---Internal runner for execute command
function M._run_execute(input)
  local safe_input = vim.fn.shellescape(input)

  -- Command: amp -x <prompt>; wait for key
  -- We want to wait for key, but also allow q/Esc via termopen callback or keymap
  local cmd =
    string.format("amp -x %s; echo ''; echo 'Press any key to close...'; read -n 1", safe_input)

  ui.float_term(cmd, {
    title = " Amp Execute ",
    width = 80,
    height = 30,
    close_on_exit = true, -- Signal UI to close automatically on exit
  })
end

---Internal runner for start with message
function M._run_start_with_message(input)
  local safe_input = vim.fn.shellescape(input)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.cmd("vsplit")
  vim.api.nvim_set_current_buf(buf)

  vim.opt_local.number = false
  vim.opt_local.relativenumber = false
  vim.opt_local.signcolumn = "no"

  -- Piping input: echo "msg" | amp --ide
  local cmd = string.format("echo %s | amp --ide", safe_input)

  vim.fn.jobstart(cmd, {
    term = true,
    on_exit = function(_, exit_code)
      if exit_code == 0 and vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end,
  })
  vim.cmd("startinsert")
end

return M
