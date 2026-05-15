-- ── nvim-tree.lua filesystem explorer ─────────────────────────────────────
-- Always shows the tree, toggle with <leader>fe

-- Icons dependency
vim.pack.add { 'https://github.com/nvim-tree/nvim-web-devicons' }
vim.pack.add { 'https://github.com/nvim-tree/nvim-tree.lua' }

local ok_devicons, devicons = pcall(require, 'nvim-web-devicons')
local ok, nvim_tree = pcall(require, 'nvim-tree')
if not ok or not ok_devicons then return end

-- Setup devicons
devicons.setup {}

-- Custom keymaps
local function on_attach(bufnr)
  local api = require 'nvim-tree.api'
  
  local function opts(desc)
    return { desc = 'nvim-tree: ' .. desc, buffer = bufnr, noremap = true, silent = true }
  end

  -- File operations
  vim.keymap.set('n', 'a', api.fs.create, opts('Create'))
  vim.keymap.set('n', 'd', api.fs.remove, opts('Delete'))
  vim.keymap.set('n', 'x', api.fs.cut, opts('Cut'))
  vim.keymap.set('n', 'p', api.fs.paste, opts('Paste'))
  
  -- Standard keymaps
  vim.keymap.set('n', '<CR>', api.node.open.edit, opts('Open'))
  vim.keymap.set('n', 'o', api.node.open.edit, opts('Open'))
  vim.keymap.set('n', 'l', api.node.open.edit, opts('Open file or expand folder'))
  vim.keymap.set('n', 'h', api.node.navigate.parent_close, opts('Close folder'))
  vim.keymap.set('n', '<Tab>', api.node.open.preview, opts('Open Preview'))
  vim.keymap.set('n', 'H', function()
    api.tree.toggle_hidden_filter()
    api.tree.toggle_gitignore_filter()
  end, opts('Toggle hidden and gitignore'))
  vim.keymap.set('n', 'R', api.tree.reload, opts('Refresh'))
  vim.keymap.set('n', 'r', api.fs.rename_basename, opts('Rename'))
  vim.keymap.set('n', 'c', api.fs.copy.node, opts('Copy'))
  vim.keymap.set('n', '?', api.tree.toggle_help, opts('Toggle help'))
end

nvim_tree.setup {
  on_attach = on_attach,
  filters = {
    dotfiles = true,
    git_ignored = true,
  },
  renderer = {
    icons = {
      show = {
        file = true,
        folder = true,
        folder_arrow = true,
        git = true,
      },
      glyphs = {
        default = '󰈔',
        symlink = '󰉆',
        bookmark = '󰆤',
        folder = {
          default = '󰉋',
          open = '󰝰',
          empty = '󰉖',
          empty_open = '󰷏',
          symlink = '󰉋',
          symlink_open = '󰝰',
        },
        git = {
          unstaged = '✗',
          staged = '✓',
          unmerged = '',
          renamed = '➜',
          untracked = '★',
          deleted = '',
          ignored = '◌',
        },
      },
    },
  },
  view = {
    width = 30,
    side = 'left',
  },
  sync_root_with_cwd = true,
  respect_buf_cwd = true,
  update_focused_file = {
    enable = true,
    update_root = false,
  },
  diagnostics = {
    enable = true,
  },
}

-- Toggle tree with <leader>fe
vim.keymap.set('n', '<leader>fe', '<cmd>NvimTreeToggle<CR>', { desc = '[F]ile [E]xplorer' })

-- Optional: auto-open on startup if in a directory (not a file)
local function open_nvim_tree(data)
  local directory = vim.fn.isdirectory(data.file) == 1
  if directory then
    vim.cmd.cd(data.file)
    nvim_tree.open()
  end
end

vim.api.nvim_create_autocmd({ 'VimEnter' }, { callback = open_nvim_tree })
