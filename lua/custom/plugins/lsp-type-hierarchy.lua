local group = vim.api.nvim_create_augroup('custom-lsp-type-hierarchy', { clear = true })

local function format_item(item)
  if item.detail and item.detail ~= '' then
    return string.format('%s %s', item.name, item.detail)
  end
  return item.name
end

local function open_type_hierarchy_telescope(kind)
  local ok_builtin, builtin = pcall(require, 'telescope.builtin')
  local ok_themes, themes = pcall(require, 'telescope.themes')
  if not (ok_builtin and ok_themes) then
    vim.notify('Telescope is not available', vim.log.levels.WARN)
    return
  end

  local method = kind == 'subtypes' and 'typeHierarchy/subtypes' or 'typeHierarchy/supertypes'
  local prepare_method = 'textDocument/prepareTypeHierarchy'
  local bufnr = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()

  local clients = vim.lsp.get_clients { bufnr = bufnr, method = prepare_method }
  if vim.tbl_isempty(clients) then
    vim.notify('No LSP client supports type hierarchy for this buffer', vim.log.levels.WARN)
    return
  end

  vim.lsp.buf_request_all(bufnr, prepare_method, function(client)
    return vim.lsp.util.make_position_params(win, client.offset_encoding)
  end, function(req_results)
    local resolved_items = {}

    for client_id, res in pairs(req_results) do
      if res and res.err and res.err.message then
        vim.notify(res.err.message, vim.log.levels.WARN)
      elseif res and res.result then
        for _, item in ipairs(res.result) do
          resolved_items[#resolved_items + 1] = { client_id = client_id, item = item }
        end
      end
    end

    if #resolved_items == 0 then
      vim.notify('No type hierarchy item resolved', vim.log.levels.INFO)
      return
    end

    local function fetch_hierarchy(selected)
      local client = vim.lsp.get_client_by_id(selected.client_id)
      if not client then
        vim.notify('LSP client disappeared while resolving hierarchy', vim.log.levels.WARN)
        return
      end

      client:request(method, { item = selected.item }, function(err, result)
        if err then
          vim.schedule(function()
            vim.notify(err.message or 'Type hierarchy request failed', vim.log.levels.ERROR)
          end)
          return
        end

        local items = result or {}
        if vim.tbl_isempty(items) then
          vim.schedule(function()
            vim.notify('No hierarchy results found', vim.log.levels.INFO)
          end)
          return
        end

        local qf_items = {}
        for _, hierarchy_item in ipairs(items) do
          local selection = hierarchy_item.selectionRange or hierarchy_item.range
          if selection then
            qf_items[#qf_items + 1] = {
              filename = vim.uri_to_fname(hierarchy_item.uri),
              lnum = selection.start.line + 1,
              col = selection.start.character + 1,
              text = format_item(hierarchy_item),
            }
          end
        end

        if vim.tbl_isempty(qf_items) then
          vim.schedule(function()
            vim.notify('Hierarchy results have no navigable positions', vim.log.levels.INFO)
          end)
          return
        end

        vim.schedule(function()
          vim.fn.setqflist({}, ' ', {
            title = kind == 'subtypes' and 'Type Hierarchy: subtypes' or 'Type Hierarchy: supertypes',
            items = qf_items,
          })

          builtin.quickfix(themes.get_dropdown {
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
        end)
      end, bufnr)
    end

    if #resolved_items == 1 then
      fetch_hierarchy(resolved_items[1])
      return
    end

    vim.ui.select(resolved_items, {
      prompt = 'Select a type hierarchy item:',
      kind = 'typehierarchy',
      format_item = function(x)
        return format_item(x.item)
      end,
    }, function(choice)
      if choice then fetch_hierarchy(choice) end
    end)
  end)
end

vim.api.nvim_create_autocmd('LspAttach', {
  group = group,
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if not client then return end

    if client.name ~= 'clangd' then return end

    vim.keymap.set('n', '<leader>st', function()
      open_type_hierarchy_telescope 'subtypes'
    end, { buffer = event.buf, desc = '[S]earch [T]ype subtypes' })

    vim.keymap.set('n', '<leader>sT', function()
      open_type_hierarchy_telescope 'supertypes'
    end, { buffer = event.buf, desc = '[S]earch type [T]op (supertypes)' })
  end,
})
