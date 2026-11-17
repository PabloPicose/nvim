-- ── smart-splits: CTRL+hjkl moves between nvim windows AND kitty splits ─────
-- At the edge of nvim the cursor jumps to the neighbouring kitty split.
-- Needs in kitty.conf: allow_remote_control + listen_on, and the
-- `--when-focus-on var:IS_NVIM` maps so kitty lets these keys through to nvim.
vim.pack.add {
  { src = 'https://github.com/smart-splits-nvim/smart-splits.nvim', version = vim.version.range '^3.0.0' },
}
-- Kitty backend only when nvim runs inside a kitty with remote control
-- (KITTY_LISTEN_ON). Over SSH or in another terminal it can never work, and
-- keeping it loaded just makes :checkhealth report errors. Still installed
-- everywhere so the lockfile is identical on every machine.
local in_kitty = vim.env.KITTY_LISTEN_ON ~= nil and vim.env.SSH_TTY == nil
vim.pack.add({ 'https://github.com/smart-splits-nvim/backend-kitty' }, { load = not in_kitty and function() end or nil })

local ok, smart_splits = pcall(require, 'smart-splits')
if ok then
  smart_splits.setup {
    move = { at_edge = 'stop' },
    -- Outside kitty: plain nvim window navigation, no multiplexer.
    mux = { backend = in_kitty and 'smart-splits-backend-kitty' or nil, warn_if_unusable = false },
  }

  vim.keymap.set('n', '<C-h>', smart_splits.move_cursor_left, { desc = 'Move focus left (nvim/kitty)' })
  vim.keymap.set('n', '<C-j>', smart_splits.move_cursor_down, { desc = 'Move focus down (nvim/kitty)' })
  vim.keymap.set('n', '<C-k>', smart_splits.move_cursor_up, { desc = 'Move focus up (nvim/kitty)' })
  vim.keymap.set('n', '<C-l>', smart_splits.move_cursor_right, { desc = 'Move focus right (nvim/kitty)' })
end
