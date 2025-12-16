-- Binary detection, download, and loading for amp-extras
local M = {}

local uv = vim.uv or vim.loop

-- ============================================================================
-- System Detection
-- ============================================================================

local system_triples = {
  mac = {
    arm64 = "aarch64-apple-darwin",
    x64 = "x86_64-apple-darwin",
  },
  linux = {
    arm64 = function(libc)
      return "aarch64-unknown-linux-" .. libc
    end,
    x64 = function(libc)
      return "x86_64-unknown-linux-" .. libc
    end,
  },
  windows = {
    x64 = "x86_64-pc-windows-msvc",
  },
}

local lib_extensions = {
  mac = ".dylib",
  linux = ".so",
  windows = ".dll",
}

--- Detect the C library type on Linux (glibc vs musl)
---@return string "gnu" or "musl"
local function detect_libc()
  local handle = io.popen("ldd --version 2>&1")
  if handle then
    local output = handle:read("*a")
    handle:close()
    if output:match("musl") then
      return "musl"
    end
  end

  -- Check for Alpine Linux
  local f = io.open("/etc/alpine-release", "r")
  if f then
    f:close()
    return "musl"
  end

  return "gnu"
end

--- Get the current system's triple
---@return string|nil triple, string|nil error
function M.get_system_triple()
  local os_name = jit and jit.os:lower() or vim.loop.os_uname().sysname:lower()
  local arch = jit and jit.arch or "x64"

  -- Normalize OS name
  if os_name == "osx" or os_name == "darwin" then
    os_name = "mac"
  elseif os_name:match("windows") or os_name == "win" then
    os_name = "windows"
  end

  -- Normalize architecture
  if arch == "arm64" or arch:match("aarch64") then
    arch = "arm64"
  else
    arch = "x64"
  end

  local os_triples = system_triples[os_name]
  if not os_triples then
    return nil, "Unsupported OS: " .. os_name
  end

  local triple = os_triples[arch]
  if not triple then
    return nil, "Unsupported architecture: " .. arch .. " on " .. os_name
  end

  -- Handle Linux libc variants
  if type(triple) == "function" then
    local libc = detect_libc()
    triple = triple(libc)
  end

  return triple
end

--- Get the library file extension for the current OS
---@return string extension (e.g., ".so", ".dylib", ".dll")
function M.get_lib_extension()
  local os_name = jit and jit.os:lower() or vim.loop.os_uname().sysname:lower()

  if os_name == "osx" or os_name == "darwin" then
    return ".dylib"
  elseif os_name:match("windows") or os_name == "win" then
    return ".dll"
  end

  return ".so"
end

-- ============================================================================
-- Path Helpers
-- ============================================================================

--- Get the plugin root directory
---@return string
function M.get_plugin_root()
  local source = debug.getinfo(1, "S").source
  local module_dir = source:match("@(.*/)")
  if module_dir then
    -- Go up from lua/amp_extras/ to plugin root
    return vim.fn.fnamemodify(module_dir, ":h:h:h")
  end
  return vim.fn.stdpath("data") .. "/lazy/amp-extras.nvim"
end

--- Get the library filename
---@return string
function M.get_lib_filename()
  return "amp_extras_core.so" -- Always .so for Lua require compatibility
end

--- Get the full path to the library
---@return string
function M.get_lib_path()
  return M.get_plugin_root() .. "/lua/amp_extras/" .. M.get_lib_filename()
end

--- Get the version file path
---@return string
function M.get_version_path()
  return M.get_plugin_root() .. "/lua/amp_extras/version"
end

-- ============================================================================
-- Version Management
-- ============================================================================

--- Get the current installed version
---@return string|nil version
function M.get_installed_version()
  local f = io.open(M.get_version_path(), "r")
  if not f then
    return nil
  end
  local version = f:read("*l")
  f:close()
  return version and version:match("^%s*(.-)%s*$") -- trim
end

--- Get the plugin's git tag/version
---@return string|nil version
function M.get_plugin_version()
  local plugin_root = M.get_plugin_root()
  local handle = io.popen(
    "git -C " .. vim.fn.shellescape(plugin_root) .. " describe --tags --exact-match 2>/dev/null"
  )
  if handle then
    local tag = handle:read("*l")
    handle:close()
    if tag and tag:match("^v") then
      return tag
    end
  end
  return nil
end

--- Save the installed version
---@param version string
function M.save_version(version)
  local f = io.open(M.get_version_path(), "w")
  if f then
    f:write(version .. "\n")
    f:close()
  end
end

-- ============================================================================
-- Download
-- ============================================================================

--- Download a file from URL to path
---@param url string
---@param dest string
---@param callback function(success: boolean, error: string|nil)
function M.download_file(url, dest, callback)
  local cmd = string.format(
    "curl -fSL --create-dirs -o %s %s 2>&1",
    vim.fn.shellescape(dest),
    vim.fn.shellescape(url)
  )

  vim.fn.jobstart(cmd, {
    on_exit = function(_, code)
      if code == 0 then
        callback(true)
      else
        callback(false, "Download failed with exit code: " .. code)
      end
    end,
  })
end

--- Download prebuilt binary from GitHub releases
---@param version string Git tag (e.g., "v0.1.0")
---@param callback function(success: boolean, error: string|nil)
function M.download_binary(version, callback)
  local triple, err = M.get_system_triple()
  if not triple then
    callback(false, err)
    return
  end

  local ext = M.get_lib_extension()
  local repo = "wrath-codes/amp-extras.nvim"
  local base_url = string.format("https://github.com/%s/releases/download/%s/", repo, version)

  local binary_url = base_url .. triple .. ext
  local checksum_url = binary_url .. ".sha256"

  local lib_path = M.get_lib_path()
  local tmp_path = lib_path .. ".tmp"
  local checksum_path = lib_path .. ".sha256"

  vim.notify("amp-extras: Downloading binary for " .. triple .. "...", vim.log.levels.INFO)

  -- Download binary
  M.download_file(binary_url, tmp_path, function(success, dl_err)
    if not success then
      callback(false, "Failed to download binary: " .. (dl_err or "unknown error"))
      return
    end

    -- Download checksum
    M.download_file(checksum_url, checksum_path, function(cs_success)
      -- Checksum download is optional, don't fail if it doesn't exist
      if cs_success then
        -- TODO: Verify checksum
      end

      -- Atomic rename
      local ok, rename_err = os.rename(tmp_path, lib_path)
      if not ok then
        callback(false, "Failed to rename binary: " .. (rename_err or "unknown"))
        return
      end

      -- Save version
      M.save_version(version)

      vim.notify("amp-extras: Binary downloaded successfully!", vim.log.levels.INFO)
      callback(true)
    end)
  end)
end

-- ============================================================================
-- Loading
-- ============================================================================

--- Check if the binary exists
---@return boolean
function M.binary_exists()
  local f = io.open(M.get_lib_path(), "r")
  if f then
    f:close()
    return true
  end
  return false
end

--- Try to load the binary module
---@return table|nil module, string|nil error
function M.load()
  local lib_path = M.get_lib_path()

  -- Add to package.cpath if needed
  local module_dir = M.get_plugin_root() .. "/lua/amp_extras/"
  if not package.cpath:match(vim.pesc(module_dir)) then
    package.cpath = module_dir .. "?.so;" .. package.cpath
  end

  local ok, result = pcall(require, "amp_extras_core")
  if ok then
    return result
  else
    return nil, result
  end
end

--- Ensure the binary is available (download if needed)
---@param opts table|nil Options: { force_download = bool, on_ready = function }
function M.ensure(opts)
  opts = opts or {}

  -- Already loaded?
  if package.loaded["amp_extras_core"] and not opts.force_download then
    if opts.on_ready then
      opts.on_ready(true)
    end
    return
  end

  -- Binary exists?
  if M.binary_exists() and not opts.force_download then
    local mod, err = M.load()
    if mod then
      if opts.on_ready then
        opts.on_ready(true)
      end
      return
    else
      vim.notify("amp-extras: Failed to load binary: " .. (err or "unknown"), vim.log.levels.WARN)
    end
  end

  -- Try to download
  local version = M.get_plugin_version()
  if not version then
    local msg =
      "amp-extras: No git tag found. Please build from source with `just build` or install a tagged release."
    vim.notify(msg, vim.log.levels.WARN)
    if opts.on_ready then
      opts.on_ready(false, msg)
    end
    return
  end

  M.download_binary(version, function(success, err)
    if success then
      -- Reload the module
      package.loaded["amp_extras_core"] = nil
      local mod, load_err = M.load()
      if mod then
        if opts.on_ready then
          opts.on_ready(true)
        end
      else
        if opts.on_ready then
          opts.on_ready(false, load_err)
        end
      end
    else
      if opts.on_ready then
        opts.on_ready(false, err)
      end
    end
  end)
end

return M
