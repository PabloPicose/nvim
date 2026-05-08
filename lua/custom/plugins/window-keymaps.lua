-- ── Resize splits with Ctrl+Arrows ────────────────────────────────────────
-- Cada pulsación mueve 3 celdas. Mantenla pulsada para redimensionar rápido.
vim.keymap.set('n', '<C-Left>',  '<C-w>3<', { desc = 'Decrease window width' })
vim.keymap.set('n', '<C-Right>', '<C-w>3>', { desc = 'Increase window width' })
vim.keymap.set('n', '<C-Up>',    '<C-w>3+', { desc = 'Increase window height' })
vim.keymap.set('n', '<C-Down>',  '<C-w>3-', { desc = 'Decrease window height' })

-- ── Escape from terminal mode ─────────────────────────────────────────────
-- Plugins like lazygit/dap-ui/neotest may open terminal buffers.
-- Without this, <Space> (leader) gets eaten as a literal character and
-- which-key / all leader keymaps stop responding.
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- ── Fit window to content (<leader>wf) ────────────────────────────────────
-- Redimensiona el split actual al mínimo espacio que necesita el buffer:
--   · Split vertical   → ajusta el ANCHO a la línea más larga + 2
--   · Split horizontal → ajusta el ALTO al número de líneas del buffer
-- Límites: nunca ocupa más del 50% del editor ni menos de 10 celdas.
vim.keymap.set('n', '<leader>wf', function()
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  -- Detect split orientation by comparing dimensions
  local win_width  = vim.api.nvim_win_get_width(win)
  local win_height = vim.api.nvim_win_get_height(win)
  local total_cols = vim.o.columns
  local total_rows = vim.o.lines - vim.o.cmdheight - 1

  local is_vertical_split = win_width < total_cols - 2

  if is_vertical_split then
    -- Fit width to longest line
    local max_len = 10
    for _, line in ipairs(lines) do
      local w = vim.fn.strdisplaywidth(line)
      if w > max_len then max_len = w end
    end
    local target = math.min(max_len + 2, math.floor(total_cols * 0.5))
    vim.api.nvim_win_set_width(win, target)
  else
    -- Fit height to number of lines
    local target = math.min(math.max(#lines, 10), math.floor(total_rows * 0.5))
    vim.api.nvim_win_set_height(win, target)
  end
end, { desc = '[W]indow [F]it to content' })
