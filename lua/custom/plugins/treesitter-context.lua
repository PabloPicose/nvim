vim.pack.add { 'https://github.com/nvim-treesitter/nvim-treesitter-context' }

local ok, context = pcall(require, 'treesitter-context')
if ok then
  context.setup {}
end
