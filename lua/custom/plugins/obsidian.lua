-- ── obsidian.nvim (community fork) ───────────────────────────────────────────
-- Wikilinks ([[Nota]], [[Nota#Heading]], [[Nota|alias]]), backlinks, completion
-- of `[[` via an in-process LSP (obsidian-ls, picked up by blink.cmp), rename
-- with link updates, tags, etc.
--
-- `gd` inside a vault note is handled in markdown.lua (delegates here).

vim.pack.add {
  { src = 'https://github.com/obsidian-nvim/obsidian.nvim', version = vim.version.range '*' },
}

local ok, obsidian = pcall(require, 'obsidian')
if not ok then return end

obsidian.setup {
  legacy_commands = false, -- will be removed in 4.0.0
  workspaces = {
    { name = 'a300m', path = '~/Documents/indra/A300mNotes' },
  },

  picker = { name = 'telescope.nvim' },

  -- Do not touch existing notes: by default obsidian.nvim rewrites the YAML
  -- frontmatter (id/aliases/tags) on every save.
  frontmatter = { enabled = false },

  -- New notes are named like in the Obsidian app: the title is the filename.
  note_id_func = function(title)
    if title and title ~= '' then return title end
    return require('obsidian.builtin').zettel_id()
  end,
  new_notes_location = 'current_dir',

  link = { style = 'wiki' },
}

-- ── Keymaps (under <leader>m, shared with the rest of markdown.lua) ─────────
-- Global: jump into the vault from anywhere.
vim.keymap.set('n', '<leader>mo', '<cmd>Obsidian quick_switch<CR>', { desc = '[M]arkdown: [O]pen vault note' })
vim.keymap.set('n', '<leader>ms', '<cmd>Obsidian search<CR>', { desc = '[M]arkdown: [S]earch vault (grep)' })
vim.keymap.set('n', '<leader>mn', '<cmd>Obsidian new<CR>', { desc = '[M]arkdown: [N]ew note' })
vim.keymap.set('n', '<leader>m#', '<cmd>Obsidian tags<CR>', { desc = '[M]arkdown: tags (#)' })

-- Buffer-local: only in vault notes.
vim.api.nvim_create_autocmd('User', {
  group = vim.api.nvim_create_augroup('custom-obsidian-keys', { clear = true }),
  pattern = 'ObsidianNoteEnter',
  callback = function(ev)
    local function map(lhs, rhs, desc, mode) vim.keymap.set(mode or 'n', lhs, rhs, { buffer = ev.buf, desc = desc }) end
    map('<leader>mb', '<cmd>Obsidian backlinks<CR>', '[M]arkdown: [B]acklinks')
    map('<leader>ml', '<cmd>Obsidian links<CR>', '[M]arkdown: [L]inks in note')
    map('<leader>mc', '<cmd>Obsidian toc<CR>', '[M]arkdown: table of [C]ontents')
    map('<leader>mR', '<cmd>Obsidian rename<CR>', '[M]arkdown: [R]ename note')
    map('<leader>mv', '<cmd>Obsidian follow_link vsplit<CR>', '[M]arkdown: follow link in [V]split')
    map('<leader>mx', '<cmd>Obsidian toggle_checkbox<CR>', '[M]arkdown: toggle checkbo[X]')
    map('<leader>ml', ':Obsidian link<CR>', '[M]arkdown: [L]ink selection to note', 'x')
    map('<leader>mn', ':Obsidian link_new<CR>', '[M]arkdown: link selection to [N]ew note', 'x')
    map('<leader>me', ':Obsidian extract_note<CR>', '[M]arkdown: [E]xtract selection to note', 'x')
  end,
})
