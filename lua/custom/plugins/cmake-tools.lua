vim.pack.add {
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/Civitasv/cmake-tools.nvim',
}

local configured = false
local executor_open = false
local runner_open = false

local function has_cmakelists_in_cwd()
  local cmakelists = vim.fs.joinpath(vim.fn.getcwd(), 'CMakeLists.txt')
  return vim.uv.fs_stat(cmakelists) ~= nil
end

local function ensure_cmake_tools_setup(force)
  if configured then return true end
  if not force and not has_cmakelists_in_cwd() then return false end

  require('cmake-tools').setup {
    cmake_executor = {
      name = 'quickfix',
      default_opts = {
        quickfix = {
          show = 'always',
          auto_close_when_success = true,
        },
      },
    },
  }

  configured = true
  return true
end

local function run_cmake_command(cmd)
  ensure_cmake_tools_setup(true)
  vim.cmd(cmd)
end

vim.api.nvim_create_autocmd({ 'VimEnter', 'DirChanged', 'BufEnter' }, {
  callback = function() ensure_cmake_tools_setup(false) end,
})

-- <leader>cm group: CMake actions
vim.keymap.set('n', '<leader>cmg', function() run_cmake_command 'CMakeGenerate' end, { desc = '[C]Make [G]enerate' })
vim.keymap.set('n', '<leader>cmb', function() run_cmake_command 'CMakeBuild' end, { desc = '[C]Make [B]uild' })
vim.keymap.set('n', '<leader>cmr', function() run_cmake_command 'CMakeRun' end, { desc = '[C]Make [R]un' })
vim.keymap.set('n', '<leader>cms', function() run_cmake_command 'CMakeSelectLaunchTarget' end, { desc = '[C]Make [S]elect launch target' })
vim.keymap.set('n', '<leader>cmT', function() run_cmake_command 'CMakeRunTest' end, { desc = '[C]Make run [T]ests' })
vim.keymap.set('n', '<leader>cmS', function() run_cmake_command 'CMakeTargetSettings' end, { desc = '[C]Make target [S]ettings' })
vim.keymap.set('n', '<leader>cmp', function() run_cmake_command 'CMakeSelectConfigurePreset' end, { desc = '[C]Make select configure [P]reset' })
vim.keymap.set('n', '<leader>cmd', function() run_cmake_command 'CMakeDebug' end, { desc = '[C]Make [D]ebug target' })
vim.keymap.set('n', '<leader>cmt', function() run_cmake_command 'CMakeStopRunner' end, { desc = '[C]Make s[t]op runner' })

vim.keymap.set('n', '<leader>cmob', function()
  ensure_cmake_tools_setup(true)
  local cmake = require 'cmake-tools'
  if executor_open then
    cmake.close_executor()
  else
    cmake.open_executor()
  end
  executor_open = not executor_open
end, { desc = '[C]Make t[o]ggle [B]uild logs' })

vim.keymap.set('n', '<leader>cmor', function()
  ensure_cmake_tools_setup(true)
  local cmake = require 'cmake-tools'
  if runner_open then
    cmake.close_runner()
  else
    cmake.open_runner()
  end
  runner_open = not runner_open
end, { desc = '[C]Make t[o]ggle [R]unner logs' })

local ok_wk, wk = pcall(require, 'which-key')
if ok_wk then
  wk.add {
    { '<leader>cm', group = '[C]Make' },
  }
end
