local n = require("nui-components")
local api = require("amp_extras.commands.dashx.api")
local form = require("amp_extras.commands.ui.dashx.form")

local M = {}

local current_renderer = nil
local resize_augroup = vim.api.nvim_create_augroup("DashXPickerResize", { clear = true })
local resize_timer = vim.loop.new_timer()

-- Persistent state for resize handling
local _state = {
  all_prompts = {},
  search_query = "",
  nodes = {},
  selected_index = 1,
}

function M.show(opts)
  opts = opts or {}
  local is_resize = opts.keep_state

  -- If opening fresh, reset state
  if not is_resize then
    _state.all_prompts = {}
    _state.search_query = ""
    _state.nodes = {}
    _state.selected_index = 1
  end

  -- Close existing renderer if any (e.g. during resize)
  if current_renderer then
    pcall(function() current_renderer:close() end)
    current_renderer = nil
  end

  -- Helper to ensure we get a valid background color for our selection cursor
  local function setup_highlights()
    -- Ensure the focus highlight group links to a standard selection group
    vim.api.nvim_set_hl(0, "NuiComponentsSelectNodeFocused", { link = "PmenuSel", default = true })
    
    local function get_color(group_name, attr)
        local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group_name, link = false })
        if not ok then return nil end
        return hl and hl[attr] or nil
    end

    -- Create a specific icon highlight that combines the Selection BG with DiagnosticWarn FG
    -- This prevents the selection foreground (usually white) from overriding the warning color
    local bg = get_color("PmenuSel", "bg") or get_color("Visual", "bg") or "#2c323c"
    local warn_fg = get_color("DiagnosticWarn", "fg") or get_color("WarningMsg", "fg") or "#e5c07b" -- Orange/Yellow
    
    vim.api.nvim_set_hl(0, "DashXSelectIcon", { fg = warn_fg, bg = bg, force = true })
  end

  setup_highlights()

  -- Calculate dimensions based on current screen size
  local total_width = vim.o.columns
  local total_height = vim.o.lines
  
  local width = math.min(120, math.floor(total_width * 0.9))
  local height = math.min(40, math.floor(total_height * 0.8))
  
  -- Determine layout mode
  local is_compact = width < 100

  -- Create a buffer for the preview
  local preview_buf = vim.api.nvim_create_buf(false, true)

  local renderer = n.create_renderer({
    width = width,
    height = height,
  })
  current_renderer = renderer

  -- Reactive signal for the UI list
  local signal = n.create_signal({
    nodes = _state.nodes,
  })

  local update_preview -- Forward declaration

  -- Logic: Filter the cached prompts based on query
  local function filter_list()
    local query = _state.search_query:lower()
    -- Split query into terms for multi-word search
    local query_terms = vim.split(query, "%s+", { trimempty = true })
    local nodes = {}

    for _, p in ipairs(_state.all_prompts) do
      local match = true
      if #query_terms > 0 then
        -- Prepare searchable text: Title + Tags
        local tags_str = (p.tags and table.concat(p.tags, " ") or "")
        local full_text = (p.title .. " " .. tags_str):lower()

        for _, term in ipairs(query_terms) do
          if not full_text:find(term, 1, true) then
            match = false
            break
          end
        end
      end

      if match then
        table.insert(
          nodes,
          n.option(
            p.title .. (p.usage_count > 0 and string.format(" (Used: %d)", p.usage_count) or ""),
            { id = p.id, _prompt = p }
          )
        )
      end
    end
    -- Update signal
    signal.nodes = nodes
    _state.nodes = nodes
    _state.selected_index = 1

    -- Manual force update
    vim.schedule(function()
      -- Ensure this renderer is still active
      if renderer ~= current_renderer then return end

      local list = renderer:get_component_by_id("prompt_list")
      if list then
        local tree = list.tree or (list.get_tree and list:get_tree())

        if tree then
          tree:set_nodes(nodes)
          tree:render()
          
          -- Reset visual cursor to top
          if list.winid and vim.api.nvim_win_is_valid(list.winid) then
             pcall(vim.api.nvim_win_set_cursor, list.winid, { 1, 0 })
          end
          
          -- Update preview for the new first item
          if nodes[1] then
             update_preview(nodes[1])
          end
        end
      end
    end)
  end

  -- Logic: Fetch from DB and update cache
  local function fetch_data()
    local ok, result = pcall(api.list_prompts)
    if ok then
      _state.all_prompts = result
      -- Normalize tags
      for _, p in ipairs(_state.all_prompts) do
        if p.tags and type(p.tags) == "string" and p.tags ~= "" then
          local ok, decoded = pcall(vim.json.decode, p.tags)
          if ok and type(decoded) == "table" then
            p.tags = decoded
          else
            p.tags = nil
          end
        end
      end
      -- Update the UI
      filter_list()
    else
      vim.notify("Failed to load prompts: " .. tostring(result), vim.log.levels.ERROR)
    end
  end

  -- Initial load (only if not resizing)
  if not is_resize then
    vim.schedule(fetch_data)
  end

  -- ... rest of style definitions ...
  local window_style = {
    highlight = {
      -- Ensure persistent background
      Normal = "NormalFloat",
      NormalNC = "NormalFloat",
      FloatBorder = "DiagnosticError",
      FloatTitle = "DiagnosticError",
    },
  }

  -- Specific style for the list
  local select_window_style = window_style

  -- Helper to choose best component for preview
  local PreviewComponent = n.buffer

  local preview_props = {
    id = "preview_buffer",
    buf = preview_buf,
    autoscroll = false,
    flex = 2,
    border_label = {
      text = "Preview",
      icon = "",
    },
    window = window_style, -- Use the shared style with correct highlights
  }

  -- Logic: Update preview based on selected node
  update_preview = function(node)
    local prompt = node._prompt
    if prompt then
      vim.schedule(function()
        -- Ensure buffer is still valid
        if not vim.api.nvim_buf_is_valid(preview_buf) then return end

        -- Enable Markdown highlighting
        vim.bo[preview_buf].buftype = "nofile"
        vim.bo[preview_buf].swapfile = false

        if vim.bo[preview_buf].filetype ~= "markdown" then
          vim.bo[preview_buf].filetype = "markdown"
        end

        -- Note: Window-local options (wrap, etc.) are best set when the window is known.
        -- Since we don't strictly know the window ID here without getting the component,
        -- we rely on the component's mounting logic or defaults.
        -- But we can try to find the window displaying this buffer if needed.
        local winids = vim.fn.win_findbuf(preview_buf)
        for _, winid in ipairs(winids) do
          vim.wo[winid].wrap = true
          vim.wo[winid].signcolumn = "no"
          vim.wo[winid].conceallevel = 2
          vim.wo[winid].concealcursor = "n"
          vim.wo[winid].spell = false
          vim.wo[winid].foldenable = false
        end

        -- Ensure TreeSitter is active
        local ok = pcall(vim.treesitter.start, preview_buf, "markdown")
        if not ok then
          vim.bo[preview_buf].syntax = "markdown"
        end

        local lines = {}

        -- Title
        table.insert(lines, "# " .. prompt.title)
        table.insert(lines, "")

        -- Metadata Table
        table.insert(lines, "| Metric | Value |")
        table.insert(lines, "| --- | --- |")
        table.insert(lines, string.format("| **Usage Count** | %d |", prompt.usage_count))

        if prompt.last_used_at then
          local last_used = os.date("%Y-%m-%d %H:%M", prompt.last_used_at)
          table.insert(lines, string.format("| **Last Used** | %s |", last_used))
        else
          table.insert(lines, "| **Last Used** | Never |")
        end

        if prompt.updated_at then
          local updated = os.date("%Y-%m-%d %H:%M", prompt.updated_at)
          table.insert(lines, string.format("| **Updated** | %s |", updated))
        end

        -- Tags
        if prompt.tags and #prompt.tags > 0 then
          local tag_str = table.concat(prompt.tags, ", ")
          table.insert(lines, string.format("| **Tags** | %s |", tag_str))
        else
          table.insert(lines, "| **Tags** | None |")
        end

        table.insert(lines, "")
        table.insert(lines, "---")
        table.insert(lines, "")

        -- Content
        local content_lines = vim.split(prompt.content, "\n")
        for _, line in ipairs(content_lines) do
          table.insert(lines, line)
        end

        -- Write to buffer
        vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)

        -- Trigger render-markdown if available
        if package.loaded["render-markdown"] then
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(preview_buf) then
              local ok, rm = pcall(require, "render-markdown")
              if ok and rm.enable then
                vim.api.nvim_buf_call(preview_buf, rm.enable)
              end
            end
          end)
        end
      end)
    end
  end

  -- Shared logic to submit a prompt
  local function submit_prompt(prompt)
    if not prompt then return end
    
    -- Usage tracking
    pcall(api.use_prompt, prompt.id)

    -- Send to Amp (Assuming amp global or module)
    local ok, amp_msg = pcall(require, "amp.message")
    if ok then
      amp_msg.send_message(prompt.content)
    else
      vim.notify("Sent prompt to Amp: " .. prompt.title)
    end

    if current_renderer then
      pcall(function() current_renderer:close() end)
      current_renderer = nil
    end
  end

  local function submit_selection()
     local node = _state.nodes[_state.selected_index]
     if node and node._prompt then
       submit_prompt(node._prompt)
     end
  end

  -- Shared mappings for CRUD operations
  local function get_crud_mappings(component_id)
    local function move_selection(direction)
      local count = #_state.nodes
      if count == 0 then return end

      local new_index = _state.selected_index + direction
      if new_index < 1 then new_index = 1 end
      if new_index > count then new_index = count end
      
      _state.selected_index = new_index

      -- Update visual selection
      local list = renderer:get_component_by_id("prompt_list")
      if list then
        local winid = list.winid
        if winid and vim.api.nvim_win_is_valid(winid) then
          pcall(vim.api.nvim_win_set_cursor, winid, { new_index, 0 })
          
          -- Force re-render for highlight update (optional if nui handles it, but safer)
          local tree = list.tree or (list.get_tree and list:get_tree())
          if tree then
             tree:render()
          end
        end
      end
      
      -- Update preview
      if _state.nodes[new_index] then
        update_preview(_state.nodes[new_index])
      end
    end

    return {
      {
        mode = { "n", "i" },
        key = "<CR>",
        handler = submit_selection,
      },
      {
        mode = { "n" },
        key = "j",
        handler = function()
          move_selection(1)
        end,
      },
      {
        mode = { "n" },
        key = "k",
        handler = function()
          move_selection(-1)
        end,
      },
      {
        mode = { "n", "i" },
        key = "<C-j>",
        handler = function()
          move_selection(1)
        end,
      },
      {
        mode = { "n", "i" },
        key = "<C-k>",
        handler = function()
          move_selection(-1)
        end,
      },
      {
        mode = { "n", "i" },
        key = "<C-n>",
        handler = function()
          renderer:close()
          form.show({
            mode = "create",
            on_success = function()
              M.show()
            end,
          })
        end,
      },
      {
        mode = { "n", "i" },
        key = "<C-e>",
        handler = function()
          -- Always try to get the selected node from the list component
          local list = renderer:get_component_by_id("prompt_list")
          if list then
            local tree = list.tree or (list.get_tree and list:get_tree())
            if tree then
              local node = tree:get_node()
              if node and node._prompt then
                renderer:close()
                form.show({
                  mode = "edit",
                  prompt = node._prompt,
                  on_success = function()
                    M.show()
                  end,
                })
              end
            end
          end
        end,
      },
      {
        mode = { "n", "i" },
        key = "<C-d>",
        handler = function()
          local list = renderer:get_component_by_id("prompt_list")
          if list then
            local tree = list.tree or (list.get_tree and list:get_tree())
            if tree then
              local node = tree:get_node()
              if node and node._prompt then
                local choice =
                  vim.fn.confirm("Delete prompt '" .. node._prompt.title .. "'?", "&Yes\n&No", 2)
                if choice == 1 then
                  pcall(api.delete_prompt, node._prompt.id)
                  fetch_data()
                end
              end
            end
          end
        end,
      },
    }
  end

  local body = function()
    -- Define components
    local search_component = n.text_input({
      id = "search_input",
      placeholder = "Search prompts by title or tag names...",
      autofocus = true,
      value = _state.search_query, -- Restore search query
      size = 3,
      max_lines = 1,
      border_label = {
        text = "Search",
        icon = "",
      },
      window = window_style,
      on_change = function(value)
        _state.search_query = value
        filter_list()
      end,
      on_mount = function(component)
        -- Force map <CR> in Insert mode to submit, overriding nui defaults
        if component.bufnr then
          vim.keymap.set("i", "<CR>", submit_selection, { buffer = component.bufnr, nowait = true })
        end
      end,
      mappings = get_crud_mappings,
    })

    local list_component = n.select({
      id = "prompt_list",
      data = signal.nodes,
      multiselect = false,
      flex = 1,
      is_focusable = false,
      border_label = {
        text = "Prompts",
        icon = "",
      },
      window = select_window_style,
      -- Enable cursorline for the unified background effect
      on_mount = function(component)
        if component.winid and vim.api.nvim_win_is_valid(component.winid) then
          vim.wo[component.winid].cursorline = true
          vim.wo[component.winid].cursorlineopt = "line"
        end
      end,
      -- Custom rendering to show usage stats
      prepare_node = function(is_selected, node, component)
        local prompt = node._prompt
        local line = n.line()

        local base_hl = "NuiComponentsSelectOption"
        local focused_hl = "NuiComponentsSelectNodeFocused"

        -- Determine focus via tree cursor
        local focused = false
        if component and component.tree and component.tree.get_node then
          local focused_node = component.tree:get_node()
          focused = focused_node and focused_node.id == node.id
        end

        local hl = focused and focused_hl or base_hl

        if not prompt then
          local text = node.text or ""
          line:append(n.text(focused and "> " or "  ", hl))
          line:append(n.text(text, hl))
          return line
        end

        if focused then
            -- Focused line: drive everything through focused_hl for consistency
            -- This ensures the entire line (text + background) looks unified and selected
            -- We use DashXSelectIcon for the icon to ensure it is yellow/orange but keeps the selection BG
            line:append(n.text("> ", "DashXSelectIcon"))
            line:append(n.text(prompt.title, focused_hl))

            if prompt.usage_count > 0 then
                line:append(n.text(" ", focused_hl))
                line:append(n.text(string.format("(Used: %d)", prompt.usage_count), focused_hl))
            end
        else
          -- Unfocused line: use distinct styling
          line:append(n.text("  ", base_hl))
          line:append(n.text(prompt.title, "Function"))

          if prompt.usage_count > 0 then
            line:append(n.text(" ", base_hl))
            line:append(n.text(string.format("(Used: %d)", prompt.usage_count), "Comment"))
          end
        end

        return line
      end,
      mappings = get_crud_mappings,
      on_select = function(node, component)
        local prompt = node._prompt
        if prompt then
          submit_prompt(prompt)
        end
      end,
      on_change = function(node)
        update_preview(node)
        -- Force redraw for selection highlight update if needed
        vim.cmd("redraw")
      end,
    })

    local preview_component = PreviewComponent(preview_props)

    local keymaps_component = n.paragraph({
      lines = "<Enter> Send | <C-n> New | <C-e> Edit | <C-d> Delete",
      align = "center",
      is_focusable = false,
      size = 3,
      border_label = {
        text = "Keymaps",
        icon = "",
      },
      window = window_style,
    })

    if is_compact then
      -- Stacked Layout
      return n.rows(
        search_component,
        n.gap(1),
        list_component,
        n.gap(1),
        preview_component,
        n.gap(1),
        keymaps_component
      )
    else
      -- Split Layout
      return n.rows(
        { flex = 1 },
        n.columns(
          { flex = 1 },
          -- Left Pane: Search & List (30%)
          n.rows(
            { flex = 1 },
            search_component,
            list_component
          ),
          -- Right Pane: Preview (70%)
          preview_component
        ),
        n.gap(1),
        keymaps_component
      )
    end
  end

  renderer:render(body)

  -- Register Autocmd for resize
  vim.api.nvim_create_autocmd("VimResized", {
    group = resize_augroup,
    callback = function()
      resize_timer:stop()
      resize_timer:start(
        50,
        0,
        vim.schedule_wrap(function()
          M.show({ keep_state = true })
        end)
      )
    end,
  })

  -- Cleanup autocmd when renderer closes
  local original_close = renderer.close
  renderer.close = function(self)
    resize_timer:stop()
    vim.api.nvim_clear_autocmds({ group = resize_augroup })
    if vim.api.nvim_buf_is_valid(preview_buf) then
      vim.api.nvim_buf_delete(preview_buf, { force = true })
    end
    if original_close then original_close(self) end
  end
end

return M