vim.pack.add {
  'https://github.com/mason-org/mason.nvim',
  'https://github.com/jay-babu/mason-nvim-dap.nvim',
}

local ok_mason, mason = pcall(require, 'mason')
if ok_mason then
  mason.setup {}
end

local ok_mason_dap, mason_nvim_dap = pcall(require, 'mason-nvim-dap')
if ok_mason_dap then
  mason_nvim_dap.setup {
    ensure_installed = { 'codelldb' },
    automatic_installation = true,
    handlers = {},
  }
end
