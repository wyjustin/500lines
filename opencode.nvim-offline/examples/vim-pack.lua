-- Neovim vim.pack snippet using a local file:// URL (Neovim 0.12+).
-- Prefer the packpath installer (./install.sh) on air-gapped machines.

local plugin = vim.fn.expand("~/opencode.nvim-offline/vendor/opencode.nvim")

vim.pack.add({
  {
    src = "file://" .. plugin,
    -- version omitted: local tree is already pinned to v1.0.0
  },
})

---@type opencode.Opts
vim.g.opencode_opts = {}

vim.keymap.set({ "n", "x" }, "<C-a>", function()
  require("opencode").ask("@this: ")
end, { desc = "Ask OpenCode…" })

vim.keymap.set({ "n", "x" }, "<C-x>", function()
  require("opencode").select()
end, { desc = "Select OpenCode…" })
