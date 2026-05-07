-- ── which-key groups for custom keymaps ───────────────────────────────────

local ok, wk = pcall(require, 'which-key')
if not ok then return end

wk.add {
  { '<leader>f', group = '[F]ile' },
  { '<leader>g', group = '[G]it' },
  { '<leader>w', group = '[W]indow' },
}
