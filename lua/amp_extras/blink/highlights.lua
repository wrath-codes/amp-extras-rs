local M = {}

function M.setup()
  -- Define highlights for our completion items if needed
  -- Currently using standard blink.cmp kinds which usually have default highlights
  -- But we can customize here if desired.

  -- Example:
  -- vim.api.nvim_set_hl(0, "AmpExtrasFile", { link = "CmpItemKindFile" })
  -- vim.api.nvim_set_hl(0, "AmpExtrasThread", { link = "CmpItemKindReference" })
end

return M
