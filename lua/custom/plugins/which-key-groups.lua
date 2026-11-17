-- ── which-key groups for custom keymaps ───────────────────────────────────

-- timeoutlen must be >= which-key delay (500ms) or which-key never shows
-- and <Space> times out as a regular cursor motion.
-- init.lua sets 300ms — override here so leader works reliably.
vim.o.timeoutlen = 600

local ok, wk = pcall(require, 'which-key')
if not ok then return end

wk.add {
  { '<leader>f', group = '[F]ile' },
  { '<leader>g', group = '[G]it' },
  { '<leader>m', group = '[M]arkdown', mode = { 'n', 'x' } },
  { '<leader>mt', group = '[T]able mode' },
  { '<leader>w', group = '[W]indow' },
}
