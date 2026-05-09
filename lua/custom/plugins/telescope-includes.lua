local ok_telescope, _ = pcall(require, 'telescope')
if not ok_telescope then return end

local function resolve_include_dir(base_dir, include_dir)
  if include_dir == '' then return nil end
  if vim.startswith(include_dir, '/') then
    return vim.fs.normalize(include_dir)
  end
  return vim.fs.normalize(vim.fs.joinpath(base_dir, include_dir))
end

local function uniq_dirs(dirs)
  local seen = {}
  local out = {}

  for _, dir in ipairs(dirs) do
    if type(dir) == 'string' and dir ~= '' then
      local abs = vim.fn.fnamemodify(dir, ':p')
      if vim.fn.isdirectory(abs) == 1 and not seen[abs] then
        seen[abs] = true
        out[#out + 1] = abs
      end
    end
  end

  return out
end

local function compact_dirs(dirs)
  table.sort(dirs, function(a, b)
    if #a == #b then return a < b end
    return #a < #b
  end)

  local compacted = {}
  for _, dir in ipairs(dirs) do
    local covered = false
    for _, parent in ipairs(compacted) do
      if dir == parent or vim.startswith(dir, parent .. '/') then
        covered = true
        break
      end
    end
    if not covered then compacted[#compacted + 1] = dir end
  end

  return compacted
end

local function parse_include_dirs_from_arguments(args, base_dir)
  local dirs = {}
  local i = 1

  while i <= #args do
    local arg = args[i]

    if arg == '-I' or arg == '-isystem' or arg == '-iquote' then
      local next_arg = args[i + 1]
      if next_arg and next_arg ~= '' then
        local resolved = resolve_include_dir(base_dir, next_arg)
        if resolved then dirs[#dirs + 1] = resolved end
      end
      i = i + 2
    elseif vim.startswith(arg, '-I') and #arg > 2 then
      local resolved = resolve_include_dir(base_dir, arg:sub(3))
      if resolved then dirs[#dirs + 1] = resolved end
      i = i + 1
    elseif vim.startswith(arg, '-isystem') and #arg > 8 then
      local resolved = resolve_include_dir(base_dir, arg:sub(9))
      if resolved then dirs[#dirs + 1] = resolved end
      i = i + 1
    elseif vim.startswith(arg, '-iquote') and #arg > 7 then
      local resolved = resolve_include_dir(base_dir, arg:sub(8))
      if resolved then dirs[#dirs + 1] = resolved end
      i = i + 1
    else
      i = i + 1
    end
  end

  return dirs
end

local function split_shell_args(command)
  local args = {}
  local current = {}
  local quote = nil
  local escaped = false

  for i = 1, #command do
    local ch = command:sub(i, i)

    if escaped then
      current[#current + 1] = ch
      escaped = false
    elseif ch == '\\' then
      escaped = true
    elseif quote then
      if ch == quote then
        quote = nil
      else
        current[#current + 1] = ch
      end
    elseif ch == '"' or ch == "'" then
      quote = ch
    elseif ch:match('%s') then
      if #current > 0 then
        args[#args + 1] = table.concat(current)
        current = {}
      end
    else
      current[#current + 1] = ch
    end
  end

  if #current > 0 then args[#args + 1] = table.concat(current) end
  return args
end

local function parse_include_dirs_from_command(command, base_dir)
  local args = split_shell_args(command or '')
  return parse_include_dirs_from_arguments(args, base_dir)
end

local function find_compile_commands_path(root)
  local candidates = {
    vim.fs.joinpath(root, 'compile_commands.json'),
    vim.fs.joinpath(root, 'build', 'compile_commands.json'),
    vim.fs.joinpath(vim.fn.getcwd(), 'compile_commands.json'),
    vim.fs.joinpath(vim.fn.getcwd(), 'build', 'compile_commands.json'),
  }

  for _, path in ipairs(candidates) do
    if vim.fn.filereadable(path) == 1 then return path end
  end

  return nil
end

local function collect_search_dirs()
  local root = vim.fs.root(0, { '.git', 'compile_commands.json', 'CMakeLists.txt' }) or vim.fn.getcwd()
  local dirs = { root }

  local compile_commands = find_compile_commands_path(root)
  if compile_commands then
    local lines = vim.fn.readfile(compile_commands)
    local ok_decode, decoded = pcall(vim.json.decode, table.concat(lines, '\n'))

    if ok_decode and type(decoded) == 'table' then
      for _, entry in ipairs(decoded) do
        if type(entry) == 'table' then
          local base_dir = entry.directory or root

          if type(entry.arguments) == 'table' then
            vim.list_extend(dirs, parse_include_dirs_from_arguments(entry.arguments, base_dir))
          elseif type(entry.command) == 'string' then
            vim.list_extend(dirs, parse_include_dirs_from_command(entry.command, base_dir))
          end
        end
      end
    end
  end

  return compact_dirs(uniq_dirs(dirs))
end

vim.keymap.set('n', '<leader>si', function()
  local ok_builtin, builtin = pcall(require, 'telescope.builtin')
  local ok_themes, themes = pcall(require, 'telescope.themes')

  if not (ok_builtin and ok_themes) then
    vim.notify('Telescope modules are not available', vim.log.levels.WARN)
    return
  end

  local search_dirs = collect_search_dirs()
  if vim.tbl_isempty(search_dirs) then
    vim.notify('No include search dirs found', vim.log.levels.WARN)
    return
  end

  local find_command = {
    'rg',
    '--files',
    '--hidden',
    '--follow',
    '--no-ignore',
    '--no-ignore-vcs',
    '-g',
    '*.h',
    '-g',
    '*.hh',
    '-g',
    '*.hpp',
    '-g',
    '*.hxx',
    '-g',
    '*.ipp',
    '-g',
    '*.inl',
    '-g',
    '*.inc',
    '-g',
    '*.tpp',
    '-g',
    '*.cuh',
    '-g',
    '!**/moc_*',
    '-g',
    '!**/moc_*.h',
  }

  builtin.find_files(themes.get_dropdown {
    prompt_title = string.format('Search [I]ncludes (.h*) [%d dirs]', #search_dirs),
    search_dirs = search_dirs,
    hidden = true,
    no_ignore = true,
    follow = true,
    find_command = find_command,
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
end, { desc = '[S]earch [I]ncludes' })
