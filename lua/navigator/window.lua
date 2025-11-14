local cursor_line = 1
local M = {}
local file_utils = require("navigator.files")

local expanded_dirs = {}

local function join_path(a, b)
  if a:sub(-1) == "/" then
    a = a:sub(1, -2)
  end
  if b:sub(1,1) == "/" then
    b = b:sub(2)
  end
  return a .. "/" .. b
end

local function highlight_dir(buf, line)
  pcall(vim.api.nvim_buf_add_highlight, buf, 0, "Directory", line, 0, -1)
end

local function apply_indents_to_buffer(buf, line_paths)
  local display = {}
  for i, item in ipairs(line_paths) do
    local path, depth = item[1], item[2]
    local name = path:match("[^/]+/?$")
    local indent = string.rep("  ", depth)
    display[i] = indent .. name
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, display)

  for i, item in ipairs(line_paths) do
    if item[1]:sub(-1) == "/" then
      highlight_dir(buf, i - 1)
    end
  end
end

function M.open_floating_window(files)
  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 1)
  local height = math.floor(vim.o.lines * 0.9)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  local line_paths = {}
  local cwd = vim.loop.cwd()

  for i, name in ipairs(files) do
    line_paths[i] = { join_path(cwd, name), 0 }
  end

  apply_indents_to_buffer(buf, line_paths)

  local function insert_files_below(cursor_line, files_to_insert, parent_path)
    local parent_depth = line_paths[cursor_line + 1][2]

    local new_line_paths = {}
    for i = 1, cursor_line + 1 do
      new_line_paths[#new_line_paths + 1] = { line_paths[i][1], line_paths[i][2] }
    end

    for _, name in ipairs(files_to_insert) do
      local path = join_path(parent_path, name)
      new_line_paths[#new_line_paths + 1] = { path, parent_depth + 1 }
    end

    for i = lp_insert, #line_paths do
      new_line_paths[#new_line_paths + 1] = line_paths[i]
    end

    line_paths = new_line_paths
    apply_indents_to_buffer(buf, line_paths)
  end

  local function collapse_dir(cursor_line, dir_path)
    local start_index = cursor_line + 2

    if start_index > #line_paths then
      expanded_dirs[dir_path] = nil
      return
    end

    local count = 0
    for i = start_index, #line_paths do
      local p = line_paths[i][1]
      if p:sub(1, #dir_path) == dir_path then
        count = count + 1
      else
        break
      end
    end

    if count == 0 then
      expanded_dirs[dir_path] = nil
      return
    end

    local new_line_paths = {}
    for i = 1, cursor_line + 1 do
      new_line_paths[#new_line_paths + 1] = { line_paths[i][1], line_paths[i][2] }
    end
    for i = start_index + count, #line_paths do
      new_line_paths[#new_line_paths + 1] = { line_paths[i][1], line_paths[i][2] }
    end

    line_paths = new_line_paths

    for k in pairs(expanded_dirs) do
      if k:sub(1, #dir_path) == dir_path then
        expanded_dirs[k] = nil
      end
    end

    apply_indents_to_buffer(buf, line_paths)
  end

  local function reexpand_saved_dirs()
    local i = 1
    while i <= #line_paths do
      local p = line_paths[i][1]
      if expanded_dirs[p] and vim.fn.isdirectory(p) ~= 0 then
        local new_files = file_utils.get_files(p) or {}
        if #new_files > 0 then
          insert_files_below(i - 1, new_files, p)
        end
      end
      i = i + 1
    end
  end

  reexpand_saved_dirs()
  vim.api.nvim_win_set_cursor(win, { cursor_line + 1, 0 })
	
  vim.keymap.set("n", "<Esc>", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, { buffer = buf, silent = true })

  vim.keymap.set("n", "<CR>", function()
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    cursor_line = cursor_pos[1] - 1
    local lp = line_paths[cursor_line + 1]
    if not lp then return end

    local path = lp[1]

    if vim.fn.isdirectory(path) ~= 0 then
      if expanded_dirs[path] then
        collapse_dir(cursor_line, path)
        expanded_dirs[path] = nil
      else
        local new_files = file_utils.get_files(path) or {}
        if #new_files > 0 then
          insert_files_below(cursor_line, new_files, path)
          expanded_dirs[path] = true
        end
      end
    else
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      vim.cmd("edit " .. path)
    end
  end, { buffer = buf, silent = true })

  return buf, win
end

return M
