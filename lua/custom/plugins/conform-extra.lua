-- ── Extra conform configuration ───────────────────────────────────────────
-- Loaded after init.lua so we can extend the conform setup done there.

local ok, conform = pcall(require, 'conform')
if not ok then return end

-- ── JSON: format with jq, 2-space indent ──────────────────────────────────
conform.formatters.jq_2 = {
  command = 'jq',
  args = { '--indent', '2', '.' },
  stdin = true,
}
conform.formatters_by_ft.json = { 'jq_2' }

-- ── JSON: always use 2-space indentation ──────────────────────────────────
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'json',
  callback = function()
    vim.bo.tabstop = 2
    vim.bo.shiftwidth = 2
    vim.bo.expandtab = true
  end,
})

-- ── Ensure jq is installed via Mason ──────────────────────────────────────
vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = function()
    local ok_reg, registry = pcall(require, 'mason-registry')
    if not ok_reg then return end
    registry.refresh(function()
      local ok_pkg, pkg = pcall(registry.get_package, 'jq')
      if ok_pkg and not pkg:is_installed() then
        pkg:install()
      end
    end)
  end,
})

-- ── <leader>cf : format buffer/selection, then apply GuessIndent ──────────
-- In visual mode conform automatically uses the selected range.
vim.keymap.set({ 'n', 'v' }, '<leader>cf', function()
  conform.format({ async = false, lsp_format = 'fallback' }, function(err)
    if not err then
      -- Re-detect indentation settings after the formatter may have changed them
      pcall(vim.cmd, 'GuessIndent auto')
    end
  end)
end, { desc = '[C]ode [F]ormat + guess indent' })
