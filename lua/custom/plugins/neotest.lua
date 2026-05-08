vim.pack.add {
  'https://github.com/nvim-neotest/neotest',
  'https://github.com/nvim-neotest/nvim-nio',
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/antoinemadec/FixCursorHold.nvim',
  'https://github.com/nvim-treesitter/nvim-treesitter',
  'https://github.com/orjangj/neotest-ctest',
}

-- ── Monkey-patch: strip TEST_PREFIX from CTest JUnit results ───────────────
--
-- POR QUÉ:
--   En cada CMakeLists.txt de tests se usa:
--     gtest_discover_tests(<Target> TEST_PREFIX "<Target>.")
--   Esto hace que CTest registre cada test con ese prefijo extra:
--     "SNFCoreTests.CoreFixture.createNodeRoot"
--   Pero neotest-ctest parsea el fichero .cpp con tree-sitter y genera:
--     "CoreFixture.createNodeRoot"
--   → Mismatch total → todos los resultados aparecen como "skipped/unknown"
--     (iconos de ojos en el summary panel).
--
-- SOLUCIÓN:
--   Se parchean dos funciones del módulo neotest-ctest.ctest en runtime:
--   · testcases()          → los nodos treesitter pueden matchear tests CTest
--   · parse_test_results() → los resultados JUnit se mapean de vuelta a nodos
--   Ambas aplican la misma regla: si el nombre tiene 3+ segmentos separados por
--   punto ("Prefix.Suite.Test"), se elimina el primero ("Suite.Test").
--
-- SI VUELVE A FALLAR:
--   1. Abre el log con <leader>pfL y busca "Unknown CTest testcase".
--   2. Compara el nombre que aparece ahí con el nombre que devuelve:
--        ctest --test-dir <build_dir> --show-only=json-v1 | grep name
--   3. Si el prefijo cambió (ej. renombraste el target CMake), actualiza
--      el patrón del match en este bloque o elimínalo si neotest-ctest
--      añade soporte nativo para TEST_PREFIX.
--
-- ALTERNATIVA LIMPIA (sin patch):
--   Quitar TEST_PREFIX de todos los gtest_discover_tests() en los
--   CMakeLists.txt de test. Eso es lo correcto si no dependes del prefijo
--   en scripts externos de CI.
do
  local ctest_mod = require 'neotest-ctest.ctest'
  local original_parse = ctest_mod.parse_test_results

  ctest_mod.parse_test_results = function(self)
    local results = original_parse(self)
    local patched = {}
    for key, value in pairs(results) do
      if key == 'summary' then
        patched[key] = value
      else
        -- If key has 3+ dot segments (Prefix.Suite.Test), strip the first one
        local prefix, rest = key:match('^([^.]+)%.(.+%..+)$')
        if prefix and rest then
          patched[rest] = value
        else
          patched[key] = value
        end
      end
    end
    return patched
  end

  -- Also patch testcases() so build_spec can match node names to CTest tests
  local original_testcases = ctest_mod.testcases

  ctest_mod.testcases = function(self)
    local cases = original_testcases(self)
    local patched = {}
    for key, value in pairs(cases) do
      local prefix, rest = key:match('^([^.]+)%.(.+%..+)$')
      if prefix and rest then
        patched[rest] = value
      else
        patched[key] = value
      end
    end
    return patched
  end

  -- ── Patch ctest:new() to use cmake-tools build directory ─────────────────
  -- PROBLEM: neotest-ctest finds the build dir by scanning for CTestTestfile.cmake
  -- up to depth 3 from the project root and picks the FIRST one (alphabetical).
  -- If multiple build dirs exist (e.g. build/actions/ and build/debug/),
  -- the wrong one gets picked → CTest runs 0 tests → all tests appear as "skipped".
  --
  -- FIX: Override ctest:new() so it scans from the cmake-tools active build
  -- directory instead of the project root. Falls back to original behavior
  -- if cmake-tools is not loaded or has no build dir configured.
  local original_new = ctest_mod.new
  ctest_mod.new = function(self, root)
    local build_dir = nil
    local ok_cmake, cmake = pcall(require, 'cmake-tools')
    if ok_cmake and type(cmake.get_build_directory) == 'function' then
      local bd = cmake.get_build_directory()
      if bd then
        build_dir = tostring(bd)
      end
    end
    return original_new(self, build_dir or root)
  end
end

-- ── neotest-ctest adapter ──────────────────────────────────────────────────
local ctest_adapter = require('neotest-ctest').setup {
  is_test_file = function(file_path)
    local name = vim.fn.fnamemodify(file_path, ':t:r')
    local ext = vim.fn.fnamemodify(file_path, ':e')
    if not vim.tbl_contains({ 'cpp', 'cc', 'cxx' }, ext) then return false end
    return name:match('Tests?$') ~= nil
      or name:match('^[Tt]est') ~= nil
      or name:match('_test$') ~= nil
  end,
  -- Only gtest for now; add "catch2", "doctest" if needed
  frameworks = { 'gtest' },
  dap_adapter = 'codelldb',
}

-- ── neotest setup ──────────────────────────────────────────────────────────
local neotest = require 'neotest'

neotest.setup {
  adapters = { ctest_adapter },
  -- Set to DEBUG while troubleshooting; switch back to WARN when stable
  log_level = vim.log.levels.DEBUG,
  discovery = {
    enabled = true,
    concurrent = 0,
    filter_dir = function(name)
      -- Skip common non-test directories
      local skip = { build = true, out = true, cmake = true, doc = true, docs = true, tools = true, scripts = true, venv = true }
      return not skip[name]
    end,
  },
  output = { open_on_run = 'short' },
  output_panel = { enabled = true, open = 'botright split | resize 15' },
  summary = {
    enabled = true,
    animated = true,
    follow = true,
    expand_errors = true,
    open = 'botright vsplit | vertical resize 40',
  },
  quickfix = { enabled = true, open = false },
  status = { enabled = true, virtual_text = true, signs = true },
  diagnostic = { enabled = true, severity = vim.diagnostic.severity.ERROR },
}

-- ── Command to open the neotest log file in a split ────────────────────────
vim.api.nvim_create_user_command('NeotestLog', function()
  local logfile = vim.fn.stdpath 'log' .. '/neotest.log'
  if vim.fn.filereadable(logfile) == 1 then
    vim.cmd('botright split ' .. vim.fn.fnameescape(logfile))
    vim.cmd 'normal! G' -- jump to end
  else
    vim.notify('Neotest log not found: ' .. logfile, vim.log.levels.WARN)
  end
end, { desc = 'Open neotest log file' })

-- ── Keymaps (<leader>ct = [C]ode [T]est) ─────────────────────────────────
vim.keymap.set('n', '<leader>ctt', function() neotest.run.run() end, { desc = 'Run nearest test' })
vim.keymap.set('n', '<leader>ctf', function() neotest.run.run(vim.fn.expand '%') end, { desc = 'Run tests in [F]ile' })
vim.keymap.set('n', '<leader>cta', function() neotest.run.run(vim.fn.getcwd()) end, { desc = 'Run [A]ll tests' })
vim.keymap.set('n', '<leader>ctl', function() neotest.run.run_last() end, { desc = 'Run [L]ast test again' })
vim.keymap.set('n', '<leader>cts', function() neotest.summary.toggle() end, { desc = 'Toggle [S]ummary panel' })
vim.keymap.set('n', '<leader>cto', function() neotest.output.open { enter = true } end, { desc = 'Open test [O]utput' })
vim.keymap.set('n', '<leader>ctO', function() neotest.output_panel.toggle() end, { desc = 'Toggle [O]utput panel' })
vim.keymap.set('n', '<leader>ctx', function() neotest.run.stop() end, { desc = 'Stop running test' })
vim.keymap.set('n', '<leader>ctw', function() neotest.watch.toggle(vim.fn.expand '%') end, { desc = 'Toggle [W]atch (rerun on save)' })
vim.keymap.set('n', '<leader>ctd', function() neotest.run.run { strategy = 'dap' } end, { desc = '[D]ebug nearest test' })
vim.keymap.set('n', '<leader>ctL', '<cmd>NeotestLog<CR>', { desc = 'Open neotest [L]og' })

local ok_wk, wk = pcall(require, 'which-key')
if ok_wk then
  wk.add {
    { '<leader>ct', group = '[T]est' },
  }
end
