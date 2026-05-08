-- ── lazygit integration and gitsigns keymaps ──────────────────────────────
-- lazygit with <leader>gg
-- gitsigns blame, blame_line, next/prev hunk commands

local ok_gitsigns, gitsigns = pcall(require, 'gitsigns')

-- ── lazygit ───────────────────────────────────────────────────────────────
vim.pack.add { 'https://github.com/kdheepak/lazygit.nvim' }
vim.keymap.set('n', '<leader>gg', '<cmd>LazyGit<CR>', { desc = '[G]it lazy[G]it' })
-- ── gitsigns keymaps ──────────────────────────────────────────────────────
-- These apply globally (not per-buffer like in kickstart/plugins/gitsigns.lua)
-- and work immediately after gitsigns is loaded.

if ok_gitsigns then
  vim.keymap.set('n', '<leader>gb', function() gitsigns.blame_line { full = true } end, { desc = 'git [b]lame line (full)' })
  vim.keymap.set('n', '<leader>gB', function() gitsigns.blame_line {} end, { desc = 'git [B]lame line' })
  vim.keymap.set('n', '<leader>gn', function() gitsigns.nav_hunk 'next' end, { desc = '[g]it [n]ext hunk' })
  vim.keymap.set('n', '<leader>gN', function() gitsigns.nav_hunk 'prev' end, { desc = '[g]it [N]ext hunk (prev)' })
end
