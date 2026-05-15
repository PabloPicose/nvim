-- JSON Language Server with SchemaStore (autocomplete + validation for known JSON files)
-- Provides VSCode-like schema support for CMakePresets.json, package.json, etc.

vim.pack.add { 'https://github.com/b0o/SchemaStore.nvim' }

-- Auto-install json-lsp via Mason
vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = function()
    local ok, registry = pcall(require, 'mason-registry')
    if not ok then return end
    registry.refresh(function()
      local ok_pkg, pkg = pcall(registry.get_package, 'json-lsp')
      if ok_pkg and not pkg:is_installed() then
        pkg:install()
      end
    end)
  end,
})

vim.lsp.config('jsonls', {
  settings = {
    json = {
      schemas = require('schemastore').json.schemas(),
      validate = { enable = true },
    },
  },
})
vim.lsp.enable 'jsonls'
