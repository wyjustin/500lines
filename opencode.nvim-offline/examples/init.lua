-- Example config for opencode.nvim (offline packpath install).
-- Copied to ~/.config/nvim/plugin/opencode-keymaps.lua when using:
--   ./install.sh --with-keymaps

---@type opencode.Opts
vim.g.opencode_opts = {
  -- Your configuration, if any. See :help or lua/opencode/config.lua
}

-- Recommended/example keymaps from upstream README
vim.keymap.set({ "n", "x" }, "<C-a>", function()
  require("opencode").ask("@this: ")
end, { desc = "Ask OpenCode…" })

vim.keymap.set({ "n", "x" }, "<C-x>", function()
  require("opencode").select()
end, { desc = "Select OpenCode…" })

vim.keymap.set({ "n", "x" }, "go", function()
  return require("opencode").operator("@this ")
end, { desc = "Append range to OpenCode", expr = true })

vim.keymap.set({ "n" }, "goo", function()
  return require("opencode").operator("@this ") .. "_"
end, { desc = "Append line to OpenCode", expr = true })

vim.keymap.set({ "n" }, "<S-C-u>", function()
  require("opencode").command("session.half.page.up")
end, { desc = "Scroll OpenCode up" })

vim.keymap.set({ "n" }, "<S-C-d>", function()
  require("opencode").command("session.half.page.down")
end, { desc = "Scroll OpenCode down" })

-- Optional: enable snacks.nvim enhancements if that plugin is installed.
-- Uncomment after installing with ./install.sh --with-snacks
--
-- pcall(function()
--   require("snacks").setup({
--     input = { enabled = true },
--     picker = { enabled = true },
--   })
-- end)
