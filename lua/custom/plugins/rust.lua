-- ── Rust IDE: rustaceanvim + crates.nvim ──────────────────────────────────
-- rust-analyzer comes from rustup:  rustup component add rust-analyzer rust-src
-- Debugging uses codelldb from Mason (see mason-dap.lua).
-- Tests go through neotest (adapter registered in neotest.lua), <leader>ct*.
--
-- Keymaps (only in Rust buffers):
--   <leader>cr  run target under cursor (fn main / test / bench)
--   <leader>cR  pick runnable (binaries, tests, examples...)
--   <leader>cl  re-run last runnable
--   <leader>cd  debug target under cursor
--   <leader>cD  pick debuggable
--   <leader>cL  re-debug last debuggable
--   <leader>cT  pick testable (cargo test targets)
--   <leader>ca  code actions (grouped, rust-analyzer flavour)
--   <leader>ce  expand macro          <leader>cE  explain error (rustc --explain)
--   <leader>ci  show diagnostic as cargo prints it
--   <leader>ck  run cargo check/clippy now (flyCheck)
--   <leader>cc  open Cargo.toml       <leader>cp  go to parent module
--   <leader>co  open docs.rs for symbol under cursor
--   <leader>cj  join lines (Rust-aware)
--   <leader>cs  structural search & replace
--   <M-k>/<M-j> move item (fn, struct, impl...) up/down
--   K           hover with actions (Enter on an action to run it)

vim.pack.add {
  { src = 'https://github.com/mrcjkb/rustaceanvim', version = vim.version.range '^9' },
  { src = 'https://github.com/saecki/crates.nvim', version = 'stable' },
}

-- ── rustaceanvim (filetype plugin: reads vim.g.rustaceanvim on first .rs) ──
vim.g.rustaceanvim = function()
  local opts = {
    tools = {
      -- Runnables open in a terminal split; tests go to neotest when available.
      executor = 'termopen',
      enable_clippy = true,
      reload_workspace_from_cargo_toml = true,
    },
    dap = {},
  }

  -- Use Mason's codelldb explicitly (better Rust type rendering than lldb-dap).
  local mason_codelldb = vim.fn.stdpath 'data' .. '/mason/packages/codelldb/extension/'
  local codelldb_path = mason_codelldb .. 'adapter/codelldb'
  local liblldb_path = mason_codelldb .. 'lldb/lib/liblldb.so'
  if vim.uv.fs_stat(codelldb_path) and vim.uv.fs_stat(liblldb_path) then
    opts.dap.adapter = require('rustaceanvim.config').get_codelldb_adapter(codelldb_path, liblldb_path)
  end

  return opts
end

-- rust-analyzer settings (rustaceanvim merges vim.lsp.config('rust-analyzer')).
vim.lsp.config('rust-analyzer', {
  settings = {
    ['rust-analyzer'] = {
      cargo = { allFeatures = true, buildScripts = { enable = true } },
      procMacro = { enable = true },
      check = { command = 'clippy' },
      inlayHints = {
        closureReturnTypeHints = { enable = 'with_block' },
        lifetimeElisionHints = { enable = 'skip_trivial' },
      },
    },
  },
})

-- ── Keymaps on rust-analyzer attach ───────────────────────────────────────
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('custom-rust-attach', { clear = true }),
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if not client or client.name ~= 'rust-analyzer' then return end

    local buf = event.buf
    local function map(keys, cmd, desc, mode)
      local rhs = type(cmd) == 'string' and function() vim.cmd(cmd) end or cmd
      vim.keymap.set(mode or 'n', keys, rhs, { buffer = buf, desc = 'Rust: ' .. desc })
    end

    -- Run / debug / test
    map('<leader>cr', 'RustLsp run', '[R]un target under cursor')
    map('<leader>cR', 'RustLsp runnables', 'pick [R]unnable')
    map('<leader>cl', 'RustLsp! runnables', 're-run [L]ast runnable')
    map('<leader>cd', 'RustLsp debug', '[D]ebug target under cursor')
    map('<leader>cD', 'RustLsp debuggables', 'pick [D]ebuggable')
    map('<leader>cL', 'RustLsp! debuggables', 're-debug [L]ast debuggable')
    map('<leader>cT', 'RustLsp testables', 'pick [T]estable')

    -- Code intelligence
    map('<leader>ca', 'RustLsp codeAction', 'code [A]ction (grouped)')
    map('<leader>ce', 'RustLsp expandMacro', '[E]xpand macro')
    map('<leader>cE', 'RustLsp explainError', '[E]xplain error')
    map('<leader>ci', 'RustLsp renderDiagnostic', '[I]nspect diagnostic (cargo style)')
    map('<leader>ck', 'RustLsp flyCheck', 'run cargo chec[K]/clippy')
    map('<leader>cc', 'RustLsp openCargo', 'open [C]argo.toml')
    map('<leader>cp', 'RustLsp parentModule', '[P]arent module')
    map('<leader>co', 'RustLsp openDocs', '[O]pen docs.rs')
    map('<leader>cj', 'RustLsp joinLines', '[J]oin lines', { 'n', 'v' })
    map('<leader>cs', function()
      local query = vim.fn.input 'SSR (e.g. foo($a) ==>> bar($a)): '
      if query ~= '' then vim.cmd('RustLsp ssr ' .. query) end
    end, '[S]tructural search & replace')
    map('<M-k>', 'RustLsp moveItem up', 'move item up')
    map('<M-j>', 'RustLsp moveItem down', 'move item down')
    map('K', 'RustLsp hover actions', 'hover actions')
  end,
})

-- ── Format Rust on save with rustfmt (via conform) ────────────────────────
local ok_conform, conform = pcall(require, 'conform')
if ok_conform then
  conform.formatters_by_ft.rust = { 'rustfmt', lsp_format = 'fallback' }
  vim.api.nvim_create_autocmd('BufWritePre', {
    group = vim.api.nvim_create_augroup('custom-rust-format', { clear = true }),
    pattern = '*.rs',
    callback = function(args) conform.format { bufnr = args.buf, timeout_ms = 2000 } end,
  })
end

-- ── crates.nvim: Cargo.toml versions, features, completion, hover ─────────
local ok_crates, crates = pcall(require, 'crates')
if ok_crates then
  crates.setup {
    lsp = { enabled = true, actions = true, completion = true, hover = true },
    completion = { crates = { enabled = true } },
  }

  vim.api.nvim_create_autocmd('BufRead', {
    group = vim.api.nvim_create_augroup('custom-crates-keys', { clear = true }),
    pattern = 'Cargo.toml',
    callback = function(args)
      local function map(keys, fn, desc, mode)
        vim.keymap.set(mode or 'n', keys, fn, { buffer = args.buf, desc = 'Crates: ' .. desc })
      end
      map('<leader>cv', crates.show_versions_popup, 'show [V]ersions')
      map('<leader>cF', crates.show_features_popup, 'show [F]eatures')
      map('<leader>cu', crates.update_crate, '[U]pdate crate', { 'n', 'v' })
      map('<leader>cU', crates.upgrade_crate, '[U]pgrade crate (major)', { 'n', 'v' })
      map('<leader>cA', crates.upgrade_all_crates, 'upgrade [A]ll crates')
      map('<leader>co', crates.open_crates_io, '[O]pen crates.io')
    end,
  })
end

-- ── which-key group ───────────────────────────────────────────────────────
local ok_wk, wk = pcall(require, 'which-key')
if ok_wk then wk.add { { '<leader>c', group = '[C]ode' } } end
