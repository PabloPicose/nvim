-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = LazyVim.safe_keymap_set
local wk = require("which-key")

wk.add({
  -- marks
  { "<leader>m", desc = "marks" },
  -- terminal
  { "<leader>t", desc = "terminal" },
})
-- TERMINAL
map("n", "<leader>th", "<cmd>ToggleTerm<cr>", { desc = "Open Horizontal Terminal" })

-- MARKS
map("n", "<leader>mc", "<cmd>delmarks!<cr>", { desc = "Delete all marks in current file" })

-- Show documentation
-- Shows if pressed upper K the documentation of the function
map("n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", { noremap = true, silent = true })
