-- Custom clangd setup for Kickstart 0.12 (vim.lsp.config + vim.lsp.enable)

vim.lsp.config('clangd', {
  filetypes = {
    'c',
    'cpp',
    'objc',
    'objcpp',
    'cuda',
    'proto',
  },
  cmd = {
    'clangd-20',
    '--header-insertion=never',
    '--query-driver=/home/ppicos/dev/emsdk/upstream/emscripten/em++,/home/ppicos/dev/emsdk/upstream/emscripten/emcc,/usr/bin/clang++,/usr/bin/g++',
  },
})

vim.lsp.enable 'clangd'
