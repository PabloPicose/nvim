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
  --
  -- ALSO: neotest-ctest computes `root` per test file by walking up to the first
  -- dir with CMakePresets.json / compile_commands.json / .clang-format / build...
  -- In a monorepo that is often a sub-project (e.g. RCGateway/) with no build dir
  -- below it → "Failed to locate CTest test directory". That happens whenever
  -- cmake-tools isn't set up (cwd without CMakeLists.txt, e.g. a Rust subfolder).
  -- So when the candidate has no CTestTestfile.cmake, keep walking up its parents.
  local function has_ctest(dir)
    if not dir or not vim.uv.fs_stat(dir) then return false end
    local found = require('plenary.scandir').scan_dir(dir, {
      respect_gitignore = false,
      depth = 3, -- same depth the original new() uses
      search_pattern = 'CTestTestfile.cmake',
      silent = true,
    })
    return #found > 0
  end

  local function find_ctest_dir(root)
    local ok_cmake, cmake = pcall(require, 'cmake-tools')
    if ok_cmake and type(cmake.get_build_directory) == 'function' then
      -- get_build_directory() errors if cmake-tools.setup() hasn't run yet
      -- (setup is lazy: only when cwd has a CMakeLists.txt)
      local ok_bd, bd = pcall(cmake.get_build_directory)
      if ok_bd and bd and has_ctest(tostring(bd)) then return tostring(bd) end
    end
    -- Walk up from root, but never past the git repo root, $HOME or 5 levels
    -- (don't scan /tmp or / and pick some unrelated project's build dir).
    local home = vim.uv.os_homedir()
    local dir = root
    for _ = 1, 5 do
      if not dir or dir == '/' or dir == home then break end
      if has_ctest(dir) then return dir end
      if vim.uv.fs_stat(vim.fs.joinpath(dir, '.git')) then break end
      local parent = vim.fs.dirname(dir)
      if parent == dir then break end
      dir = parent
    end
    return nil
  end

  local original_new = ctest_mod.new
  ctest_mod.new = function(self, root)
    local dir = find_ctest_dir(root)
    if not dir then
      error(('No CTest build dir found from %s up: configure & build with CMake first'):format(root))
    end
    return original_new(self, dir)
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

-- Rust tests: rustaceanvim's adapter (discovery via rust-analyzer).
-- Load rust.lua first so vim.g.rustaceanvim is set before rustaceanvim
-- initializes its config (require caches it, so it won't run twice).
local adapters = { ctest_adapter }
pcall(require, 'custom.plugins.rust')
local ok_rust_adapter, rust_adapter = pcall(require, 'rustaceanvim.neotest')
if ok_rust_adapter then table.insert(adapters, rust_adapter) end

-- ── Rust consumer: rediscovery + "run all" that works from anywhere ───────
-- rustaceanvim discovers tests by asking rust-analyzer (experimental/runnables).
-- Two consequences:
--   1. rust-analyzer only starts when a .rs buffer gets filetype=rust. If you open
--      nvim in a repo and press <leader>cta from a C++ file / the file tree /
--      the dashboard, there is NO rust-analyzer → 0 Rust tests → nothing runs.
--   2. Even once started, neotest scans before rust-analyzer finished indexing,
--      so files come back empty until a rescan (rust.lua → tools.on_initialized).
-- run_all() handles both: it boots rust-analyzer for every cargo project under
-- cwd (loading one .rs file in a hidden buffer) and, if tests aren't known yet,
-- queues the run until on_initialized → refresh() has rediscovered them.
local rust_skip_dirs = { target = true, node_modules = true, build = true, out = true, venv = true }

-- Cargo project roots: the one containing cwd, or any below it (depth-limited).
local function cargo_roots()
  local cwd = vim.fn.getcwd()
  local up = vim.fs.root(cwd, 'Cargo.toml')
  if up then return { up } end
  local roots = {}
  for name, type in vim.fs.dir(cwd, {
    depth = 4,
    skip = function(dir) return not rust_skip_dirs[vim.fs.basename(dir)] and not vim.fs.basename(dir):match '^%.' end,
  }) do
    if type == 'file' and vim.fs.basename(name) == 'Cargo.toml' then
      local dir = vim.fs.joinpath(cwd, vim.fs.dirname(name))
      -- keep only the outermost one (workspace root, not every member)
      local nested = vim.iter(roots):any(function(r) return vim.startswith(dir, r .. '/') end)
      if not nested then
        roots = vim.tbl_filter(function(r) return not vim.startswith(r, dir .. '/') end, roots)
        table.insert(roots, dir)
      end
    end
  end
  return roots
end

local function has_rust_analyzer(root)
  for _, c in ipairs(vim.lsp.get_clients { name = 'rust-analyzer' }) do
    if c.root_dir and (c.root_dir == root or vim.startswith(root, c.root_dir .. '/')) then return true end
  end
  return false
end

-- Start rust-analyzer for `root` by loading one of its .rs files in a hidden buffer.
local function boot_rust_analyzer(root)
  local file
  for _, rel in ipairs { 'src/lib.rs', 'src/main.rs' } do
    local f = vim.fs.joinpath(root, rel)
    if vim.uv.fs_stat(f) then file = f break end
  end
  file = file
    or vim.fs.find(function(n) return n:match '%.rs$' end, { path = root, type = 'file', limit = 1 })[1]
  if not file then return false end
  local buf = vim.fn.bufadd(file)
  vim.cmd('noswapfile call bufload(' .. buf .. ')') -- no E325 if another nvim has it open
  if vim.bo[buf].filetype ~= 'rust' then
    vim.api.nvim_buf_call(buf, function() vim.cmd 'setfiletype rust' end)
  end
  return true
end

local function rust_consumer(client)
  local nio = require 'nio'
  local pending_run = false

  local function tree_has_tests(tree)
    for _, pos in tree:iter() do
      if pos.type == 'test' then return true end
    end
    return false
  end

  -- Must run inside a nio task. Returns how many adapters were launched.
  local function run_discovered()
    local launched = 0
    for _, id in ipairs(client:get_adapters()) do
      local tree = client:get_position(nil, { adapter = id })
      if tree and tree_has_tests(tree) then
        launched = launched + 1
        -- Launch from the main loop, like a keymap would: each adapter gets its own
        -- task, and we're not inside a fast-event context (after an LSP await),
        -- where adapters calling vim.o/vim.fn fail with E5560 and nio.gather then
        -- cancels every sibling ("Task was cancelled").
        vim.schedule(function() require('neotest').run.run { suite = true, adapter = id } end)
      end
    end
    return launched
  end

  local function rust_adapter_has_tests()
    for _, id in ipairs(client:get_adapters()) do
      if id:match '^rustaceanvim:' then
        local tree = client:get_position(nil, { adapter = id })
        if tree and tree_has_tests(tree) then return true end
      end
    end
    return false
  end

  -- Rescan Rust adapters; if a run-all is queued and tests now exist, fire it.
  local function rescan()
    client:get_adapters() -- ensures neotest started & adapters registered
    for adapter_id in pairs(client._adapters or {}) do
      local root = adapter_id:match '^rustaceanvim:(.+)$'
      if root then client:_update_positions(root, { adapter = adapter_id }) end
    end
    if pending_run and rust_adapter_has_tests() then
      pending_run = false
      run_discovered()
    end
  end

  return {
    refresh = function() nio.run(rescan) end,

    run_all = function()
      local roots = cargo_roots()
      local booted = false
      for _, root in ipairs(roots) do
        if not has_rust_analyzer(root) and boot_rust_analyzer(root) then booted = true end
      end
      nio.run(function()
        if #roots == 0 or (not booted and rust_adapter_has_tests()) then
          if run_discovered() == 0 then
            vim.schedule(function() vim.notify('neotest: no tests discovered', vim.log.levels.WARN) end)
          end
          return
        end
        -- Rust tests not known yet → queue the run; on_initialized → refresh() fires it.
        pending_run = true
        vim.schedule(function()
          vim.notify('neotest: waiting for rust-analyzer to index; tests will run when ready…', vim.log.levels.INFO)
        end)
        -- rust-analyzer was already up (maybe already indexed) → rescan right away
        -- If there still are no Rust tests, don't leave it queued: run the rest now.
        if not booted then
          rescan()
          if pending_run then
            pending_run = false
            run_discovered()
          end
        end
      end)
    end,
  }
end

neotest.setup {
  adapters = adapters,
  consumers = { rust_rediscover = rust_consumer },
  -- Set to DEBUG while troubleshooting; switch back to WARN when stable
  log_level = vim.log.levels.DEBUG,
  discovery = {
    enabled = true,
    concurrent = 0,
    filter_dir = function(name)
      -- Skip common non-test directories
      local skip = { build = true, out = true, cmake = true, doc = true, docs = true, tools = true, scripts = true, venv = true, target = true, node_modules = true }
      return not skip[name] and not name:match '^%.' -- also .git, .venv, .cache...
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
-- Run the whole suite of every adapter (cargo workspaces, ctest build dir...).
-- Boots rust-analyzer if needed, so it works from any buffer / any cwd.
vim.keymap.set('n', '<leader>cta', function() neotest.rust_rediscover.run_all() end, { desc = 'Run [A]ll tests' })
vim.keymap.set('n', '<leader>ctr', function() neotest.rust_rediscover.refresh() end, { desc = '[R]ediscover Rust tests' })
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
