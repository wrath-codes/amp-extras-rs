local M = {}

M.command = function()
  vim.fn.jobstart({ "amp", "logout" }, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        local msg = table.concat(data, "\n")
        msg = vim.trim(msg)
        if msg ~= "" then
          vim.schedule(function()
            vim.notify(msg, vim.log.levels.INFO, { title = "Amp Logout" })
          end)
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        local msg = table.concat(data, "\n")
        msg = vim.trim(msg)
        if msg ~= "" then
          vim.schedule(function()
            vim.notify(msg, vim.log.levels.ERROR, { title = "Amp Logout" })
          end)
        end
      end
    end,
  })
end

return M
