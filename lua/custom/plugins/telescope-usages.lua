local ok_builtin, builtin = pcall(require, 'telescope.builtin')
if not ok_builtin then return end

local ok_themes, themes = pcall(require, 'telescope.themes')
if not ok_themes then return end

local group = vim.api.nvim_create_augroup('custom-telescope-usages', { clear = true })

vim.api.nvim_create_autocmd('LspAttach', {
  group = group,
  callback = function(event)
    vim.keymap.set('n', '<leader>su', function()
      builtin.lsp_references(themes.get_dropdown {
        include_declaration = false,
        show_line = false,
        trim_text = true,
        jump_type = 'never',
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
    end, { buffer = event.buf, desc = '[S]earch [U]sages (references)' })
  end,
})
