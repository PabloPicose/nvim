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
