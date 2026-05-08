-- GitHub Copilot (migrated from lazy.nvim style to vim.pack)

vim.pack.add { 'https://github.com/zbirenbaum/copilot.lua' }

local ok, copilot = pcall(require, 'copilot')
if not ok then return end

copilot.setup {
  suggestion = {
    enabled = true,
    auto_trigger = false,
    hide_during_completion = true,
    keymap = {
      accept = false,
      -- More terminal-friendly than <M-[>/<M-]>
      next = '<C-j>',
      prev = '<C-k>',
    },
  },
  panel = { enabled = false },
  filetypes = {
    markdown = true,
    help = true,
    lua = true,
    cpp = true,
    c = true,
  },
}

local suggestion = require 'copilot.suggestion'

vim.keymap.set('i', '<C-g>', function()
  if suggestion.is_visible() then
    suggestion.accept()
  else
    suggestion.next()
  end
end, { desc = 'Copilot trigger or accept' })

vim.api.nvim_create_autocmd('TextChangedI', {
  callback = function()
    if suggestion.is_visible() then
      suggestion.dismiss()
    end
  end,
})
