# amp-extras.nvim

A Rust-powered Neovim plugin for enhanced [Amp CLI](https://ampcode.com) integration.

## Features

- **Send Commands** - Send buffer, selection, file references to Amp
- **Prompt Library (DashX)** - Store and organize reusable prompts with SQLite
- **Session Management** - Start Amp sessions with optional initial messages
- **Lualine Integration** - Status line component for Amp

## Requirements

- Neovim 0.10+
- [Amp CLI](https://ampcode.com) installed and configured
- [sourcegraph/amp.nvim](https://github.com/sourcegraph/amp.nvim) for message sending

## Installation

### lazy.nvim (with pre-built binaries)

```lua
{
  "wrath-codes/amp-extras.nvim",
  lazy = false,
  dependencies = { "sourcegraph/amp.nvim" },
  config = function()
    require("amp_extras").setup({})

    -- Optional: Register which-key groups
    local wk = require("which-key")
    wk.add({
      { "<leader>a", group = "Amp", mode = { "n", "v" } },
      { "<leader>as", group = "Send", mode = { "n", "v" } },
      { "<leader>al", group = "Account" },
      { "<leader>ap", group = "Prompts" },
      { "<leader>ai", group = "Interactive" },
    })
  end,
}
```

### lazy.nvim (build from source)

```lua
{
  "wrath-codes/amp-extras.nvim",
  lazy = false,
  dependencies = { "sourcegraph/amp.nvim" },
  build = "just build",
  config = function()
    require("amp_extras").setup({})
  end,
}
```

## Configuration

```lua
require("amp_extras").setup({
  lazy = false,       -- Lazy load the plugin
  prefix = "a",       -- Keymap prefix (mappings will be <leader> + prefix)

  -- Feature flags
  features = {
    send = true,      -- Send commands (buffer, selection, line, file)
    message = true,   -- Send message UI
    login = true,     -- Login/Logout commands
    update = true,    -- Update command
    dashx = true,     -- DashX prompts
    session = true,   -- Session management
    lualine = true,   -- Lualine integration
  },

  -- Keymap overrides (string = custom keymap, false = disable)
  keymaps = {
    send_selection = true,      -- <leader>ash
    send_selection_ref = true,  -- <leader>asl
    send_buffer = true,         -- <leader>asb
    send_file_ref = true,       -- <leader>asf
    send_line_ref = true,       -- <leader>asr
    send_message = true,        -- <leader>asm
    login = true,               -- <leader>ali
    logout = true,              -- <leader>alo
    update = true,              -- <leader>au
    dashx_list = true,          -- <leader>apl
    dashx_execute = true,       -- <leader>apx
    session_new = true,         -- <leader>ain
    session_msg = true,         -- <leader>aim
  },
})
```

## Default Keymaps

| Keymap | Mode | Description |
|--------|------|-------------|
| `<leader>ash` | v | Send Selection (Content) |
| `<leader>asl` | v | Send Selection (Ref) |
| `<leader>asb` | n | Send Buffer (Content) |
| `<leader>asf` | n | Send File (Ref) |
| `<leader>asr` | n | Send Line (Ref) |
| `<leader>asm` | n | Send Message UI |
| `<leader>ali` | n | Amp Login |
| `<leader>alo` | n | Amp Logout |
| `<leader>au` | n | Amp Update |
| `<leader>apl` | n | DashX: List Prompts |
| `<leader>apx` | n | DashX: Execute Prompt |
| `<leader>ain` | n | New Session |
| `<leader>aim` | n | Session with Message |

## Commands

| Command | Description |
|---------|-------------|
| `:AmpSendBuffer` | Send current buffer content |
| `:AmpSendSelection` | Send visual selection content |
| `:AmpSendSelectionRef` | Send visual selection as reference |
| `:AmpSendFileRef` | Send current file as reference |
| `:AmpSendLineRef` | Send current line as reference |
| `:AmpSendMessage` | Open message input UI |
| `:AmpLogin` | Login to Amp |
| `:AmpLogout` | Logout from Amp |
| `:AmpUpdate` | Update Amp CLI |
| `:AmpDashX` | Open DashX prompt picker |
| `:AmpExecute` | Quick execute a prompt |
| `:AmpSession` | Start new Amp session |
| `:AmpSessionWithMessage` | Start session with initial message |

## Lualine Integration

```lua
require("lualine").setup({
  sections = {
    lualine_x = {
      { require("amp_extras.lualine").component },
    },
  },
})
```

## Development

```bash
# Build the project
just build

# Run tests
just test

# Format code
just fmt

# Run linter
just lint
```

## Supported Platforms

Pre-built binaries are available for:
- Linux x86_64 (glibc)
- Linux aarch64 (glibc)
- macOS Intel (x86_64)
- macOS Apple Silicon (aarch64)
- Windows x86_64

## License

MIT
