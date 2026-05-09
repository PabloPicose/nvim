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

local function switch_source_header()
  local bufnr = vim.api.nvim_get_current_buf()
  local clangd_clients = vim.lsp.get_clients { bufnr = bufnr, name = 'clangd' }

  if vim.tbl_isempty(clangd_clients) then
    vim.notify('clangd is not attached to this buffer', vim.log.levels.WARN)
    return
  end

  local params = { uri = vim.uri_from_bufnr(bufnr) }

  clangd_clients[1]:request('textDocument/switchSourceHeader', params, function(err, result)
    if err then
      vim.schedule(function()
        vim.notify('switchSourceHeader failed: ' .. (err.message or 'unknown error'), vim.log.levels.ERROR)
      end)
      return
    end

    if type(result) ~= 'string' or result == '' then
      vim.schedule(function()
        vim.notify('No corresponding source/header found', vim.log.levels.INFO)
      end)
      return
    end

    vim.schedule(function()
      vim.cmd.edit(vim.uri_to_fname(result))
    end)
  end, bufnr)
end

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
  callback = function(ev)
    vim.keymap.set('n', '<leader>ch', switch_source_header, {
      buffer = ev.buf,
      desc = '[C]langd switc[h] source/header',
    })
  end,
})
