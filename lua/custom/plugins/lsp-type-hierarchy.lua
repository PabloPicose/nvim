local group = vim.api.nvim_create_augroup('custom-lsp-type-hierarchy', { clear = true })

vim.api.nvim_create_autocmd('LspAttach', {
  group = group,
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if not client then return end

    if client.name ~= 'clangd' then return end

    vim.keymap.set('n', '<leader>st', function()
      if type(vim.lsp.buf.typehierarchy) ~= 'function' then
        vim.notify('type hierarchy is not available in this Neovim version', vim.log.levels.WARN)
        return
      end
      vim.lsp.buf.typehierarchy 'subtypes'
    end, { buffer = event.buf, desc = '[S]earch [T]ype subtypes' })

    vim.keymap.set('n', '<leader>sT', function()
      if type(vim.lsp.buf.typehierarchy) ~= 'function' then
        vim.notify('type hierarchy is not available in this Neovim version', vim.log.levels.WARN)
        return
      end
      vim.lsp.buf.typehierarchy 'supertypes'
    end, { buffer = event.buf, desc = '[S]earch type [T]op (supertypes)' })
  end,
})
