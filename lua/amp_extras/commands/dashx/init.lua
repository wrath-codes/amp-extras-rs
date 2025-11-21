local M = {}
local api = require("amp_extras.commands.dashx.api")

---Seed default prompts if the library is empty
local function seed_defaults()
    local ok, prompts = pcall(api.list_prompts)
    if ok and #prompts == 0 then
        local defaults = {
            {
                title = "Explain Code",
                content = "Explain the following code in detail, focusing on the logic and potential edge cases:",
                tags = {"coding", "explanation"}
            },
            {
                title = "Refactor Selection",
                content = "Refactor the selected code to be more idiomatic, performant, and readable. Explain your changes.",
                tags = {"coding", "refactor"}
            },
            {
                title = "Find Bugs",
                content = "Analyze the selected code for potential bugs, race conditions, or security vulnerabilities.",
                tags = {"coding", "debug"}
            },
            {
                title = "Generate Unit Tests",
                content = "Write comprehensive unit tests for the selected code, covering happy paths and error cases.",
                tags = {"coding", "testing"}
            },
            {
                title = "Add Documentation",
                content = "Add detailed documentation comments to the selected code, following standard conventions.",
                tags = {"coding", "docs"}
            }
        }

        for _, p in ipairs(defaults) do
            pcall(api.create_prompt, p.title, p.content, p.tags)
        end
        vim.notify("DashX: Seeded default prompts", vim.log.levels.INFO)
    end
end

function M.setup()
    -- Register commands
    vim.api.nvim_create_user_command("AmpDashX", function()
        require("amp_extras.commands.ui.dashx.picker").show()
    end, { desc = "Open DashX Prompt Library" })
    
    -- Auto-seed defaults
    vim.schedule(seed_defaults)
end

return M
