-- ── Markdown tools ──────────────────────────────────────────────────────────

-- ── Interactive table formatter ─────────────────────────────────────────────
-- Remap vim-table-mode's prefix away from <leader>t to avoid clash with <leader>tm
vim.g.table_mode_map_prefix = '<leader>T'
vim.pack.add { 'https://github.com/dhruvasagar/vim-table-mode' }
vim.keymap.set('n', '<leader>tt', '<cmd>TableModeToggle<CR>', { desc = '[T]oggle [T]able mode' })

-- ── render-markdown.nvim ─────────────────────────────────────────────────────
vim.pack.add { 'https://github.com/MeanderingProgrammer/render-markdown.nvim' }

local ok, rm = pcall(require, 'render-markdown')
if ok then
  rm.setup { file_types = { 'markdown' } }
end

vim.keymap.set('n', '<leader>tm', '<cmd>RenderMarkdown toggle<CR>', { desc = '[T]oggle [M]arkdown render' })

-- ── Follow markdown links with gd ────────────────────────────────────────────
local accent_map = {
  ['á'] = 'a', ['à'] = 'a', ['ä'] = 'a', ['â'] = 'a', ['ã'] = 'a', ['å'] = 'a',
  ['Á'] = 'a', ['À'] = 'a', ['Ä'] = 'a', ['Â'] = 'a', ['Ã'] = 'a', ['Å'] = 'a',
  ['é'] = 'e', ['è'] = 'e', ['ë'] = 'e', ['ê'] = 'e',
  ['É'] = 'e', ['È'] = 'e', ['Ë'] = 'e', ['Ê'] = 'e',
  ['í'] = 'i', ['ì'] = 'i', ['ï'] = 'i', ['î'] = 'i',
  ['Í'] = 'i', ['Ì'] = 'i', ['Ï'] = 'i', ['Î'] = 'i',
  ['ó'] = 'o', ['ò'] = 'o', ['ö'] = 'o', ['ô'] = 'o', ['õ'] = 'o',
  ['Ó'] = 'o', ['Ò'] = 'o', ['Ö'] = 'o', ['Ô'] = 'o', ['Õ'] = 'o',
  ['ú'] = 'u', ['ù'] = 'u', ['ü'] = 'u', ['û'] = 'u',
  ['Ú'] = 'u', ['Ù'] = 'u', ['Ü'] = 'u', ['Û'] = 'u',
  ['ñ'] = 'n', ['Ñ'] = 'n', ['ç'] = 'c', ['Ç'] = 'c',
}

local function normalize_text(text)
  for from, to in pairs(accent_map) do
    text = text:gsub(from, to)
  end
  return text
end

-- Normalizes headings and anchors to comparable ids.
local function text_to_anchor(text)
  return normalize_text(text):lower():gsub('^#', ''):gsub('[^%w%s%-]', ''):gsub('%s+', '-'):gsub('%-+', '-'):gsub('^%-+', ''):gsub('%-+$', '')
end

local function jump_to_anchor(anchor)
  local expected_anchor = text_to_anchor(anchor)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for lnum, l in ipairs(lines) do
    local heading = l:match('^#+%s+(.+)$')
    if heading and text_to_anchor(heading) == expected_anchor then
      vim.api.nvim_win_set_cursor(0, { lnum, 0 })
      vim.cmd.normal { 'zz', bang = true }
      return true
    end
  end
  return false
end

local function follow_markdown_link()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1  -- 1-indexed

  -- Find [text](target) span that contains the cursor
  local target = nil
  local s = 1
  while true do
    local ts, te, _, t = line:find('%[.-%]%((.-)%)', s)
    if not ts then break end
    if col >= ts and col <= te then
      target = t
      break
    end
    s = te + 1
  end

  if not target then
    local only_target = nil
    local count = 0
    for t in line:gmatch('%[.-%]%((.-)%)') do
      count = count + 1
      if count == 1 then only_target = t end
    end

    if count == 1 then
      target = only_target
    else
      vim.notify('No markdown link under cursor', vim.log.levels.INFO)
      return
    end
  end

  -- Skip external URLs
  if target:match('^https?://') or target:match('^mailto:') then
    vim.notify('External link: ' .. target, vim.log.levels.INFO)
    return
  end

  -- Split file_part and anchor_part
  local file_part, anchor_part = target:match('^(.-)#(.+)$')
  if not file_part then
    if target:sub(1, 1) == '#' then
      file_part, anchor_part = '', target:sub(2)
    else
      file_part, anchor_part = target, nil
    end
  end

  -- Record current location in jumplist so <C-o> returns correctly.
  vim.cmd.normal { "m'", bang = true }

  -- Navigate to file if specified
  if file_part ~= '' then
    local dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':h')
    local abs = vim.fn.fnamemodify(dir .. '/' .. file_part, ':p')
    if vim.fn.filereadable(abs) == 0 then
      vim.notify('File not found: ' .. file_part, vim.log.levels.WARN)
      return
    end
    vim.cmd.edit(vim.fn.fnameescape(abs))
  end

  -- Jump to anchor heading if specified
  if anchor_part then
    if not jump_to_anchor(anchor_part) then
      vim.notify('Heading not found: #' .. anchor_part, vim.log.levels.WARN)
    end
  end
end

local markdown_nav_group = vim.api.nvim_create_augroup('custom-markdown-nav', { clear = true })

local function set_markdown_gd(buf)
  vim.keymap.set('n', 'gd', follow_markdown_link, { buffer = buf, desc = 'Follow markdown link' })
end

vim.api.nvim_create_autocmd('FileType', {
  group = markdown_nav_group,
  pattern = 'markdown',
  callback = function(ev) set_markdown_gd(ev.buf) end,
})

-- Ensure markdown link navigation keeps priority even if an LSP later remaps `gd`.
vim.api.nvim_create_autocmd('LspAttach', {
  group = markdown_nav_group,
  callback = function(ev)
    if vim.bo[ev.buf].filetype == 'markdown' then set_markdown_gd(ev.buf) end
  end,
})
