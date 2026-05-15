-- ── General toggle keymaps ──────────────────────────────────────────────────

-- Toggle inlay hints globally (parameter names, return types in C++, Rust, etc.)
vim.keymap.set('n', '<leader>tv', function()
  local enabled = vim.lsp.inlay_hint.is_enabled()
  vim.lsp.inlay_hint.enable(not enabled)
  vim.notify('Inlay hints ' .. (not enabled and 'enabled' or 'disabled'), vim.log.levels.INFO)
end, { desc = '[T]oggle [V]irtual hints' })
