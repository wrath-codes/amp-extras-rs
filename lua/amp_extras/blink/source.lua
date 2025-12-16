local M = {}

---@class BlinkSource
local Source = {}

---@return string[]
function Source.get_trigger_characters()
  return { "@" }
end

---@param context blink.cmp.Context
---@return boolean
function Source.is_available(context)
  -- Only available when amp_message_context is true (set by message buffer)
  return vim.b[context.bufnr].amp_message_context == true
end

---@param context blink.cmp.Context
---@param callback fun(items: blink.cmp.CompletionItem[])
function Source.get_completions(context, callback)
  -- Get the prefix after the '@'
  -- The trigger character '@' is included in the context check but we need to find where it is
  local line = context.line
  local col = context.cursor[2]

  -- Simple pattern matching to find the query after @
  -- This handles cases like "Hello @some" -> query="some"
  local trigger_pos = nil
  local query = ""

  -- Search backwards for @
  for i = col, 1, -1 do
    local char = line:sub(i, i)
    if char == "@" then
      trigger_pos = i
      break
    end
    if char:match("%s") then
      -- Stop at whitespace, assume not a valid trigger
      break
    end
  end

  if not trigger_pos then
    callback({})
    return
  end

  query = line:sub(trigger_pos + 1, col)

  -- We want to search for both files and threads
  -- We can run them in parallel if we had async Lua, but our Rust call is synchronous and fast

  local core = require("amp_extras_core")
  local items = {}

  -- 1. File completions
  -- Call Rust FFI
  local files = core.autocomplete("file", query)
  if files then
    for _, file in ipairs(files) do
      table.insert(items, {
        label = file,
        kind = require("blink.cmp.types").CompletionItemKind.File,
        insertText = "@" .. file,
        sortText = "0_" .. file, -- Prioritize files (optional)
        filterText = "@" .. file,
        labelDetails = {
          detail = "File",
        },
        documentation = {
          kind = "markdown",
          value = string.format("**File**: `%s`", file),
        },
      })
    end
  end

  -- 2. Thread completions
  local threads = core.autocomplete("thread", query)
  if threads then
    for _, thread_str in ipairs(threads) do
      -- thread_str is "ID: Title"
      local id, title = thread_str:match("^(T%-[%w-]+):%s*(.+)$")
      if not id then
        -- Fallback if format doesn't match
        id = thread_str
        title = ""
      end

      table.insert(items, {
        label = title ~= "" and title or id,
        kind = require("blink.cmp.types").CompletionItemKind.Reference,
        insertText = "@" .. id,
        sortText = "1_" .. (title ~= "" and title or id),
        filterText = "@" .. id .. " " .. title,
        labelDetails = {
          detail = id,
          description = "Thread",
        },
        documentation = {
          kind = "markdown",
          value = string.format("**Thread**\n\n**ID**: `%s`\n**Title**: %s", id, title),
        },
      })
    end
  end

  callback({
    is_incomplete_forward = false,
    is_incomplete_backward = false,
    items = items,
  })
end

function M.new()
  return setmetatable({}, { __index = Source })
end

return M
