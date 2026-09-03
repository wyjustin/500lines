-- lazy.nvim spec for the offline copy.
--
-- Use AFTER: ./install.sh --for-lazy
-- Do NOT also install into pack/*/start (./install.sh with no flags),
-- or Neovim will load the plugin twice (duplicate autocmds / event handlers).
--
-- Drop this file into lua/plugins/ or merge the table into lazy.setup({...}).

return {
  {
    "nickjvandyke/opencode.nvim",
    -- Local tree: lazy will not git-clone GitHub.
    dir = vim.fn.stdpath("data") .. "/offline-plugins/opencode.nvim",
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

  -- Only if you ran: ./install.sh --for-lazy --with-snacks
  -- Skip this block if snacks.nvim is already in lazy.setup() from another spec.
  -- {
  --   "folke/snacks.nvim",
  --   dir = vim.fn.stdpath("data") .. "/offline-plugins/snacks.nvim",
  --   version = false,
  --   opts = {
  --     input = { enabled = true },
  --     picker = { enabled = true },
  --   },
  -- },
}
