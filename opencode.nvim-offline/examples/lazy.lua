-- lazy.nvim snippet for an already-extracted offline copy.
-- Point `dir` at vendor/opencode.nvim from this package (or the packpath install).

return {
  {
    "nickjvandyke/opencode.nvim",
    -- Local directory: no git clone / no network
    dir = vim.fn.stdpath("data") .. "/site/pack/offline/start/opencode.nvim",
    version = false,
    config = function()
      ---@type opencode.Opts
      vim.g.opencode_opts = {}

      vim.keymap.set({ "n", "x" }, "<C-a>", function()
        require("opencode").ask("@this: ")
      end, { desc = "Ask OpenCode…" })

      vim.keymap.set({ "n", "x" }, "<C-x>", function()
        require("opencode").select()
      end, { desc = "Select OpenCode…" })
    end,
  },

  -- Optional. Only if you installed snacks via ./install.sh --with-snacks
  -- {
  --   "folke/snacks.nvim",
  --   dir = vim.fn.stdpath("data") .. "/site/pack/offline/start/snacks.nvim",
  --   version = false,
  --   opts = {
  --     input = { enabled = true },
  --     picker = { enabled = true },
  --   },
  -- },
}
