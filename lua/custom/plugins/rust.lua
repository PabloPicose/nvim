-- ── Rust IDE: rustaceanvim + crates.nvim ──────────────────────────────────
-- rust-analyzer comes from rustup:  rustup component add rust-analyzer rust-src
-- Debugging uses codelldb from Mason (see mason-dap.lua).
-- Tests go through neotest (adapter registered in neotest.lua), <leader>ct*.
--
-- Keymaps: everything Rust-specific lives under <leader>cr ([C]ode → [R]ust),
-- buffer-local, so it never collides with other languages.
--
--  .rs buffers (rust-analyzer attached)        Cargo.toml buffers (crates.nvim)
--   <leader>crr  run target under cursor        <leader>crv  show versions
--   <leader>crR  pick runnable                  <leader>crf  show features
--   <leader>crl  re-run last runnable           <leader>crd  show dependencies
--   <leader>crd  debug target under cursor      <leader>crp  crate popup (details)
--   <leader>crD  pick debuggable                <leader>cru  update crate (n/v)
--   <leader>crL  re-debug last debuggable       <leader>crU  upgrade crate, major (n/v)
--   <leader>crt  pick testable                  <leader>cra  update all crates
--   <leader>crT  tests related to cursor        <leader>crA  upgrade all crates
--   <leader>cra  code action (grouped)          <leader>crx  plain crate → inline table
--   <leader>cre  expand macro                   <leader>crX  extract crate → [table]
--   <leader>crE  explain error (rustc)          <leader>cro  open crates.io
--   <leader>cri  diagnostic, cargo style        <leader>crD  open docs
--   <leader>crI  related diagnostics            <leader>crH  open homepage
--   <leader>crk  cargo check/clippy now         <leader>crG  open repository
--   <leader>crK  clear check diagnostics
--   <leader>crc  open Cargo.toml                Not under <leader>cr:
--   <leader>crp  parent module                    <M-k>/<M-j> move item up/down
--   <leader>cro  docs.rs for symbol               K           hover with actions
--   <leader>crO  external docs (std/local)        Tests via neotest: <leader>ct*
--   <leader>crj  join lines (n/v)
--   <leader>crs  structural search & replace
--   <leader>crw  workspace symbols  (W: + deps)
--   <leader>crv… view: t syntax tree, h HIR, m MIR, g crate graph
--   <leader>crS… server: r reload workspace, p rebuild proc macros,
--                        R restart rust-analyzer, l log file

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
      -- rust-analyzer finished indexing → rescan tests for neotest (see neotest.lua).
      on_initialized = function()
        local ok, neotest = pcall(require, 'neotest')
        if ok and neotest.rust_rediscover then neotest.rust_rediscover.refresh() end
      end,
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
    map('<leader>crr', 'RustLsp run', '[R]un target under cursor')
    map('<leader>crR', 'RustLsp runnables', 'pick [R]unnable')
    map('<leader>crl', 'RustLsp! runnables', 're-run [L]ast runnable')
    map('<leader>crd', 'RustLsp debug', '[D]ebug target under cursor')
    map('<leader>crD', 'RustLsp debuggables', 'pick [D]ebuggable')
    map('<leader>crL', 'RustLsp! debuggables', 're-debug [L]ast debuggable')
    map('<leader>crt', 'RustLsp testables', 'pick [T]estable')
    map('<leader>crT', 'RustLsp relatedTests', 'related [T]ests')

    -- Code intelligence
    map('<leader>cra', 'RustLsp codeAction', 'code [A]ction (grouped)')
    map('<leader>cre', 'RustLsp expandMacro', '[E]xpand macro')
    map('<leader>crE', 'RustLsp explainError', '[E]xplain error')
    map('<leader>cri', 'RustLsp renderDiagnostic', '[I]nspect diagnostic (cargo style)')
    map('<leader>crI', 'RustLsp relatedDiagnostics', 'related d[I]agnostics')
    map('<leader>crk', 'RustLsp flyCheck run', 'run cargo chec[K]/clippy')
    map('<leader>crK', 'RustLsp flyCheck clear', 'clear chec[K] diagnostics')
    map('<leader>crc', 'RustLsp openCargo', 'open [C]argo.toml')
    map('<leader>crp', 'RustLsp parentModule', '[P]arent module')
    map('<leader>cro', 'RustLsp openDocs', '[O]pen docs.rs')
    map('<leader>crO', 'RustLsp externalDocs', '[O]pen external docs')
    map('<leader>crj', 'RustLsp joinLines', '[J]oin lines', { 'n', 'v' })
    map('<leader>crs', function()
      local query = vim.fn.input 'SSR (e.g. foo($a) ==>> bar($a)): '
      if query ~= '' then vim.cmd('RustLsp ssr ' .. query) end
    end, '[S]tructural search & replace')
    map('<leader>crw', 'RustLsp workspaceSymbol', '[W]orkspace symbols')
    map('<leader>crW', 'RustLsp! workspaceSymbol', '[W]orkspace symbols (+ deps)')

    -- View internals
    map('<leader>crvt', 'RustLsp syntaxTree', 'syntax [T]ree')
    map('<leader>crvh', 'RustLsp view hir', '[H]IR')
    map('<leader>crvm', 'RustLsp view mir', '[M]IR')
    map('<leader>crvg', 'RustLsp crateGraph', 'crate [G]raph')

    -- rust-analyzer server
    map('<leader>crSr', 'RustLsp reloadWorkspace', '[R]eload workspace')
    map('<leader>crSp', 'RustLsp rebuildProcMacros', 'rebuild [P]roc macros')
    map('<leader>crSR', 'RustAnalyzer restart', '[R]estart rust-analyzer')
    map('<leader>crSl', 'RustLsp logFile', '[L]og file')

    -- Not leader-based
    map('<M-k>', 'RustLsp moveItem up', 'move item up')
    map('<M-j>', 'RustLsp moveItem down', 'move item down')
    map('K', 'RustLsp hover actions', 'hover actions')

    local ok_wk, wk = pcall(require, 'which-key')
    if ok_wk then
      wk.add {
        { '<leader>cr', group = '[R]ust', buffer = buf, mode = { 'n', 'v' } },
        { '<leader>crv', group = '[V]iew internals', buffer = buf },
        { '<leader>crS', group = '[S]erver (rust-analyzer)', buffer = buf },
      }
    end
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
      map('<leader>crv', crates.show_versions_popup, 'show [V]ersions')
      map('<leader>crf', crates.show_features_popup, 'show [F]eatures')
      map('<leader>crd', crates.show_dependencies_popup, 'show [D]ependencies')
      map('<leader>crp', crates.show_crate_popup, 'crate [P]opup')
      map('<leader>cru', crates.update_crate, '[U]pdate crate', { 'n', 'v' })
      map('<leader>crU', crates.upgrade_crate, '[U]pgrade crate (major)', { 'n', 'v' })
      map('<leader>cra', crates.update_all_crates, 'update [A]ll crates')
      map('<leader>crA', crates.upgrade_all_crates, 'upgrade [A]ll crates (major)')
      map('<leader>crx', crates.expand_plain_crate_to_inline_table, 'e[X]pand to inline table')
      map('<leader>crX', crates.extract_crate_into_table, 'e[X]tract into table')
      map('<leader>cro', crates.open_crates_io, '[O]pen crates.io')
      map('<leader>crD', crates.open_documentation, 'open [D]ocs')
      map('<leader>crH', crates.open_homepage, 'open [H]omepage')
      map('<leader>crG', crates.open_repository, 'open repository ([G]it)')

      local ok_wk, wk = pcall(require, 'which-key')
      if ok_wk then wk.add { { '<leader>cr', group = '[R]ust (crates)', buffer = args.buf, mode = { 'n', 'v' } } } end
    end,
  })
end

-- ── which-key group ───────────────────────────────────────────────────────
local ok_wk, wk = pcall(require, 'which-key')
if ok_wk then wk.add { { '<leader>c', group = '[C]ode' } } end
