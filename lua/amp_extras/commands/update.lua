local M = {}

M.command = function()
  vim.fn.jobstart({ "amp", "update" }, {
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          local msg = vim.trim(line)
          if msg ~= "" then
            vim.schedule(function()
              vim.notify(msg, vim.log.levels.INFO, { title = "Amp Update" })
            end)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          local msg = vim.trim(line)
          if msg ~= "" then
            -- Only treat as error if it looks like an actual error
            -- Often stderr is used for progress messages in CLI tools
            local level = vim.log.levels.INFO
            if
              msg:lower():match("^error")
              or msg:lower():match("^fatal")
              or msg:lower():match("^fail")
            then
              level = vim.log.levels.ERROR
            elseif msg:lower():match("^warn") then
              level = vim.log.levels.WARN
            end

            vim.schedule(function()
              vim.notify(msg, level, { title = "Amp Update" })
            end)
          end
        end
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        vim.schedule(function()
          vim.notify(
            "Amp update failed with exit code " .. code,
            vim.log.levels.ERROR,
            { title = "Amp Update" }
          )
        end)
      end
    end,
  })
end

return M
