local ok_builtin, builtin = pcall(require, 'telescope.builtin')
if not ok_builtin then return end

local ok_themes, themes = pcall(require, 'telescope.themes')
if not ok_themes then return end

-- Fuzzy search inside the current buffer.
-- Wider window, prompt on top, and live preview while moving through matches.
vim.keymap.set('n', '<leader>sb', function()
  builtin.current_buffer_fuzzy_find(themes.get_dropdown {
    winblend = 10,
    previewer = true,
    sorting_strategy = 'ascending',
    layout_strategy = 'horizontal',
    layout_config = {
      prompt_position = 'top',
      width = 0.95,
      height = 0.85,
      preview_width = 0.6,
    },
  })
end, { desc = '[S]earch in current [B]uffer' })
