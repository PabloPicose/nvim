vim.pack.add {
  'https://github.com/mfussenegger/nvim-dap',
  'https://github.com/nvim-neotest/nvim-nio', -- required by nvim-dap-ui
  'https://github.com/rcarriga/nvim-dap-ui',
  'https://github.com/theHamsta/nvim-dap-virtual-text',
  'https://github.com/Weissle/persistent-breakpoints.nvim',
  'https://github.com/nvim-telescope/telescope-dap.nvim',
  'https://github.com/jonboh/nvim-dap-rr',
}

local dap = require 'dap'
local dapui = require 'dapui'

-- ── Adapters ───────────────────────────────────────────────────────────────
dap.adapters.codelldb = {
  type = 'server',
  port = '${port}',
  executable = {
    command = vim.fn.stdpath 'data' .. '/mason/bin/codelldb',
    args = { '--port', '${port}' },
  },
}

-- ── Configurations ─────────────────────────────────────────────────────────
dap.configurations.cpp = {
  {
    name = 'Launch (select file)',
    type = 'codelldb',
    request = 'launch',
    program = function()
      local ok, cmake = pcall(require, 'cmake-tools')
      local default_dir = vim.fn.getcwd() .. '/build/'
      if ok and type(cmake.get_build_directory) == 'function' then
        local bd = cmake.get_build_directory()
        if bd then default_dir = tostring(bd) .. '/' end
      end
      return vim.fn.input('Path to executable: ', default_dir, 'file')
    end,
    cwd = '${workspaceFolder}',
    stopOnEntry = false,
    args = {},
  },
}
dap.configurations.c = dap.configurations.cpp

-- ── nvim-dap-ui ────────────────────────────────────────────────────────────
dapui.setup {
  icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
  controls = {
    icons = {
      pause = '⏸',
      play = '▶',
      step_into = '⏎',
      step_over = '⏭',
      step_out = '⏮',
      step_back = 'b',
      run_last = '▶▶',
      terminate = '⏹',
      disconnect = '⏏',
    },
  },
}

-- Auto open/close dapui with session
dap.listeners.after.event_initialized['dapui_config'] = dapui.open
dap.listeners.before.event_terminated['dapui_config'] = dapui.close
dap.listeners.before.event_exited['dapui_config'] = dapui.close

-- ── nvim-dap-virtual-text ──────────────────────────────────────────────────
local vt = require 'nvim-dap-virtual-text'
vt.setup {}
local vt_enabled = true

-- ── persistent-breakpoints ─────────────────────────────────────────────────
require('persistent-breakpoints').setup {
  save_dir = vim.fn.stdpath 'data' .. '/dap_breakpoints',
  load_breakpoints_event = { 'BufReadPost' },
}

-- ── telescope-dap ──────────────────────────────────────────────────────────
pcall(require('telescope').load_extension, 'dap')

-- ── keymaps ────────────────────────────────────────────────────────────────
local pb = require 'persistent-breakpoints.api'

vim.keymap.set('n', '<leader>db', pb.toggle_breakpoint, { desc = '[D]AP toggle [b]reakpoint' })
vim.keymap.set('n', '<leader>dB', function()
  pb.set_conditional_breakpoint(vim.fn.input 'Breakpoint condition: ')
end, { desc = '[D]AP conditional [B]reakpoint' })
vim.keymap.set('n', '<leader>dc', dap.continue, { desc = '[D]AP [c]ontinue' })
vim.keymap.set('n', '<leader>dr', dap.run_to_cursor, { desc = '[D]AP [r]un to cursor' })
vim.keymap.set('n', '<leader>di', dap.step_into, { desc = '[D]AP step [i]nto' })
vim.keymap.set('n', '<leader>do', dap.step_over, { desc = '[D]AP step [o]ver' })
vim.keymap.set('n', '<leader>dO', dap.step_out, { desc = '[D]AP step [O]ut' })
vim.keymap.set('n', '<leader>ds', dap.terminate, { desc = '[D]AP [s]top debugging' })

vim.keymap.set('n', '<leader>du', dapui.toggle, { desc = '[D]AP toggle [u]i' })
vim.keymap.set({ 'n', 'v' }, '<leader>de', function() dapui.eval(nil, { enter = true }) end, { desc = '[D]AP [e]val expression' })

vim.keymap.set('n', '<leader>dv', function()
  if vt_enabled then
    vt.disable()
  else
    vt.enable()
  end
  vt_enabled = not vt_enabled
end, { desc = '[D]AP toggle [v]irtual text' })

-- Telescope DAP pickers
vim.keymap.set('n', '<leader>dl', function() require('telescope').extensions.dap.list_breakpoints() end, { desc = '[D]AP [l]ist breakpoints' })
vim.keymap.set('n', '<leader>dC', function() require('telescope').extensions.dap.configurations() end, { desc = '[D]AP [C]onfigurations' })
vim.keymap.set('n', '<leader>dF', function() require('telescope').extensions.dap.frames() end, { desc = '[D]AP [F]rames' })
vim.keymap.set('n', '<leader>dV', function() require('telescope').extensions.dap.variables() end, { desc = '[D]AP [V]ariables' })

-- ── which-key group ────────────────────────────────────────────────────────
local ok_wk, wk = pcall(require, 'which-key')
if ok_wk then
  wk.add { { '<leader>d', group = '[D]AP' } }
end
