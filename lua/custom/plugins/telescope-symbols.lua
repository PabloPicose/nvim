local ok_builtin, builtin = pcall(require, 'telescope.builtin')
if not ok_builtin then return end

vim.keymap.set('n', '<leader>fs', builtin.lsp_document_symbols, { desc = '[F]ind document [S]ymbols' })
vim.keymap.set('n', '<leader>fS', builtin.lsp_dynamic_workspace_symbols, { desc = '[F]ind workspace [S]ymbols' })
