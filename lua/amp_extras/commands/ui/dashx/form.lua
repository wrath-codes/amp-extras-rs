local n = require("nui-components")
local api = require("amp_extras.commands.dashx.api")

local M = {}

---@class DashXFormProps
---@field mode "create"|"edit"
---@field prompt Prompt?
---@field on_success fun(prompt: Prompt)

---Show the Create/Edit Prompt Form
---@param props DashXFormProps
function M.show(props)
  local is_edit = props.mode == "edit"
  local prompt = props.prompt or { title = "", content = "", tags = nil }

  -- Convert tags array to comma-separated string
  local tags_str = ""
  if prompt.tags and #prompt.tags > 0 then
    tags_str = table.concat(prompt.tags, ", ")
  end

  local renderer = n.create_renderer({
    width = 80,
    height = 30,
  })

  local window_style = {
    highlight = {
      FloatBorder = "DiagnosticError",
      FloatTitle = "DiagnosticError",
    },
  }

  local form_component = n.form({
    id = "prompt_form",
    submit_key = "<C-s>", -- Ctrl+s to save
    on_submit = function(is_valid)
      if not is_valid then
        vim.notify("Please fix the errors in the form", vim.log.levels.ERROR)
        return
      end

      local component = renderer:get_component_by_id("prompt_form")
      if not component then return end
      
      -- Get values via IDs - workaround for component access
      -- n.form doesn't pass values directly in on_submit yet in all versions, 
      -- so we might need to grab them from the inputs if available, 
      -- or rely on component state if n.form supports it.
      -- Assuming newer nui-components where we can access children or state.
      
      -- Actually, best way in nui-components is often binding signals or accessing by ID
      local title_comp = renderer:get_component_by_id("title_input")
      local tags_comp = renderer:get_component_by_id("tags_input")
      local content_comp = renderer:get_component_by_id("content_input")

      local title = title_comp:get_current_value()
      local tags_val = tags_comp:get_current_value()
      local content = content_comp:get_current_value()

      -- Process tags
      local tags = {}
      for tag in string.gmatch(tags_val, "([^,]+)") do
        table.insert(tags, vim.trim(tag))
      end
      if #tags == 0 then tags = nil end

      -- Call API
      local success, result
      if is_edit then
        success, result = pcall(api.update_prompt, prompt.id, title, content, tags)
      else
        success, result = pcall(api.create_prompt, title, content, tags)
      end

      if success then
        vim.notify("Prompt " .. (is_edit and "updated" or "created"), vim.log.levels.INFO)
        renderer:close()
        if props.on_success then
          props.on_success(result)
        end
      else
        vim.notify("Error: " .. tostring(result), vim.log.levels.ERROR)
      end
    end
  }, n.rows(
    n.text_input({
      id = "title_input",
      border_label = "Title",
      placeholder = "e.g., Refactor Code",
      value = prompt.title,
      validate = n.validator.min_length(3),
      autofocus = true,
      window = window_style,
    }),
    n.gap(1),
    n.text_input({
      id = "tags_input",
      border_label = "Tags (comma separated)",
      placeholder = "rust, logic, testing",
      value = tags_str,
      window = window_style,
    }),
    n.gap(1),
    n.text_input({
      id = "content_input",
      border_label = "Prompt Content",
      placeholder = "Enter your prompt here...",
      value = prompt.content,
      flex = 1,
      window = window_style,
    }),
    n.gap(1),
    n.paragraph({
      lines = "Press <C-s> to save, <Esc> to cancel",
      align = "center",
      is_focusable = false,
      border_label = "Actions",
      window = window_style,
    })
  ))

  renderer:render(form_component)
end

return M
