-- Custom clangd setup for Kickstart 0.12 (vim.lsp.config + vim.lsp.enable)

vim.lsp.config('clangd', {
  filetypes = {
    'c',
    'cpp',
    'objc',
    'objcpp',
    'cuda',
    'proto',
  },
  cmd = {
    'clangd-20',
    '--header-insertion=never',
    '--query-driver=/home/ppicos/dev/emsdk/upstream/emscripten/em++,/home/ppicos/dev/emsdk/upstream/emscripten/emcc,/usr/bin/clang++,/usr/bin/g++',
  },
})

vim.lsp.enable 'clangd'

local function request_switch_source_header(bufnr, on_result)
  local clangd_clients = vim.lsp.get_clients { bufnr = bufnr, name = 'clangd' }

  if vim.tbl_isempty(clangd_clients) then
    vim.notify('clangd is not attached to this buffer', vim.log.levels.WARN)
    return
  end

  local params = { uri = vim.uri_from_bufnr(bufnr) }

  clangd_clients[1]:request('textDocument/switchSourceHeader', params, function(err, result)
    if err then
      vim.schedule(function()
        vim.notify('switchSourceHeader failed: ' .. (err.message or 'unknown error'), vim.log.levels.ERROR)
      end)
      return
    end

    if type(result) ~= 'string' or result == '' then
      vim.schedule(function()
        vim.notify('No corresponding source/header found', vim.log.levels.INFO)
      end)
      return
    end

    on_result(vim.uri_to_fname(result))
  end, bufnr)
end

local function switch_source_header()
  local bufnr = vim.api.nvim_get_current_buf()
  request_switch_source_header(bufnr, function(path)
    vim.schedule(function()
      vim.cmd.edit(vim.fn.fnameescape(path))
    end)
  end)
end

local function is_header_path(path)
  local ext = vim.fn.fnamemodify(path, ':e'):lower()
  return ext == 'h' or ext == 'hh' or ext == 'hpp' or ext == 'hxx' or ext == 'inl' or ext == 'ipp' or ext == 'tpp'
end

local function is_editable_window(win)
  if not vim.api.nvim_win_is_valid(win) then return false end
  local buf = vim.api.nvim_win_get_buf(win)
  return vim.bo[buf].buftype == ''
end

local function find_horizontal_neighbors(current_win)
  local cur_pos = vim.api.nvim_win_get_position(current_win)
  local cur_row = cur_pos[1]
  local cur_col = cur_pos[2]
  local cur_height = vim.api.nvim_win_get_height(current_win)

  local left_win = nil
  local right_win = nil
  local left_col = -1
  local right_col = math.huge

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= current_win and is_editable_window(win) then
      local pos = vim.api.nvim_win_get_position(win)
      local row = pos[1]
      local col = pos[2]
      local height = vim.api.nvim_win_get_height(win)

      local overlap = math.min(cur_row + cur_height, row + height) - math.max(cur_row, row)
      if overlap > 0 then
        if col < cur_col and col > left_col then
          left_col = col
          left_win = win
        elseif col > cur_col and col < right_col then
          right_col = col
          right_win = win
        end
      end
    end
  end

  return left_win, right_win
end

local function edit_in_window(win, path)
  vim.api.nvim_win_call(win, function()
    vim.cmd.edit(vim.fn.fnameescape(path))
  end)
end

local function normalize_locations(result)
  if not result then return {} end

  local locations = result
  if not vim.islist(locations) then locations = { locations } end

  local out = {}
  for _, loc in ipairs(locations) do
    local uri = loc.uri or loc.targetUri
    local range = loc.range or loc.targetSelectionRange or loc.targetRange
    if uri and range and range.start then
      out[#out + 1] = {
        path = vim.uri_to_fname(uri),
        line = range.start.line + 1,
        col = range.start.character + 1,
      }
    end
  end

  return out
end

local function jump_in_window(win, location)
  vim.api.nvim_win_call(win, function()
    vim.cmd.edit(vim.fn.fnameescape(location.path))
    vim.api.nvim_win_set_cursor(win, { location.line, location.col })
    vim.cmd.normal { 'zvzz', bang = true }

    local prev = vim.w.peek_definition_match_id
    if type(prev) == 'number' and prev > 0 then pcall(vim.fn.matchdelete, prev) end
    vim.w.peek_definition_match_id = vim.fn.matchaddpos('IncSearch', { { location.line } }, 20)

    local bufnr = vim.api.nvim_get_current_buf()
    local aug = vim.api.nvim_create_augroup('clangd-peek-clear-' .. win, { clear = true })
    vim.api.nvim_create_autocmd('CursorMoved', {
      group = aug,
      buffer = bufnr,
      once = true,
      callback = function()
        vim.api.nvim_win_call(win, function()
          local mid = vim.w.peek_definition_match_id
          if type(mid) == 'number' and mid > 0 then
            pcall(vim.fn.matchdelete, mid)
            vim.w.peek_definition_match_id = nil
          end
        end)
      end,
    })
  end)
end

local function peek_definition_in_right_split()
  local bufnr = vim.api.nvim_get_current_buf()
  local current_win = vim.api.nvim_get_current_win()

  local clients = vim.lsp.get_clients { bufnr = bufnr, name = 'clangd', method = 'textDocument/definition' }
  if vim.tbl_isempty(clients) then
    vim.notify('clangd does not support definition in this buffer', vim.log.levels.WARN)
    return
  end

  vim.lsp.buf_request_all(bufnr, 'textDocument/definition', function(client)
    return vim.lsp.util.make_position_params(current_win, client.offset_encoding)
  end, function(results)
    local definitions = {}

    for _, res in pairs(results) do
      if res and res.err and res.err.message then
        vim.schedule(function() vim.notify(res.err.message, vim.log.levels.WARN) end)
      elseif res and res.result then
        vim.list_extend(definitions, normalize_locations(res.result))
      end
    end

    if vim.tbl_isempty(definitions) then
      vim.schedule(function()
        vim.notify('No definition found', vim.log.levels.INFO)
      end)
      return
    end

    local target = definitions[1]

    vim.schedule(function()
      local left_neighbor, right_neighbor = find_horizontal_neighbors(current_win)
      local target_win = right_neighbor or left_neighbor

      if not target_win then
        vim.api.nvim_set_current_win(current_win)
        vim.cmd.vsplit()
        target_win = vim.api.nvim_get_current_win()
      end

      jump_in_window(target_win, target)
      vim.api.nvim_set_current_win(current_win)
    end)
  end)
end

local function switch_source_header_side_by_side()
  local bufnr = vim.api.nvim_get_current_buf()
  local current_win = vim.api.nvim_get_current_win()
  local current_path = vim.api.nvim_buf_get_name(bufnr)

  if current_path == '' then
    vim.notify('Current buffer has no file path', vim.log.levels.WARN)
    return
  end

  request_switch_source_header(bufnr, function(other_path)
    vim.schedule(function()
      local current_is_header = is_header_path(current_path)
      local other_is_header = is_header_path(other_path)

      local header_path = current_is_header and current_path or other_path
      local source_path = current_is_header and other_path or current_path

      if not current_is_header and not other_is_header then
        source_path = current_path
        header_path = other_path
      end

      local left_neighbor, right_neighbor = find_horizontal_neighbors(current_win)
      local left_win
      local right_win

      if left_neighbor and right_neighbor then
        if current_is_header then
          left_win = left_neighbor
          right_win = current_win
        else
          left_win = current_win
          right_win = right_neighbor
        end
      elseif right_neighbor then
        left_win = current_win
        right_win = right_neighbor
      elseif left_neighbor then
        left_win = left_neighbor
        right_win = current_win
      else
        left_win = current_win
        vim.api.nvim_set_current_win(current_win)
        vim.cmd.vsplit()
        right_win = vim.api.nvim_get_current_win()
      end

      edit_in_window(left_win, source_path)
      edit_in_window(right_win, header_path)

      if current_is_header then
        vim.api.nvim_set_current_win(right_win)
      else
        vim.api.nvim_set_current_win(left_win)
      end
    end)
  end)
end

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
  callback = function(ev)
    vim.keymap.set('n', '<leader>ch', switch_source_header, {
      buffer = ev.buf,
      desc = '[C]langd switc[h] source/header',
    })

    vim.keymap.set('n', '<leader>cH', switch_source_header_side_by_side, {
      buffer = ev.buf,
      desc = '[C]langd switch source/[H]eader side-by-side',
    })

    vim.keymap.set('n', 'gD', peek_definition_in_right_split, {
      buffer = ev.buf,
      desc = '[G]oto [D]efinition in right split (peek)',
    })
  end,
})
