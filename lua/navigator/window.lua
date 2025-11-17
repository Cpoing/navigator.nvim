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
  local screen_w = vim.o.columns
  local screen_h = vim.o.lines

  local total_width = math.floor(screen_w * 0.9)
  local total_height = math.floor(screen_h * 0.9)
  local row = math.floor((screen_h - total_height) / 2)
  local col = math.floor((screen_w - total_width) / 2)

  local left_width = math.floor(total_width * 0.3)
  local right_width = total_width - left_width

  local tree_buf = vim.api.nvim_create_buf(false, true)
  local tree_opts = {
    relative = "editor",
    width = left_width,
    height = total_height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  }
  local tree_win = vim.api.nvim_open_win(tree_buf, true, tree_opts)

  local preview_buf = vim.api.nvim_create_buf(false, true)

  local preview_opts = {
    relative = "editor",
    width = right_width,
    height = total_height,
    row = row,
    col = col + left_width + 2,
    style = "minimal",
    border = "rounded",
  }

  local preview_win = vim.api.nvim_open_win(preview_buf, false, preview_opts)

	-- previews first file?
	-- then previews whatever our cursor is on
  vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, {})

  local line_paths = {}
  local cwd = vim.loop.cwd()

  for i, name in ipairs(files) do
    line_paths[i] = { join_path(cwd, name), 0 }
  end

  apply_indents_to_buffer(tree_buf, line_paths)

  -- vim.api.nvim_win_set_cursor(tree_win, { cursor_line + 1, 0 })
  vim.o.cursorline = true

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

    for i = cursor_line + 2, #line_paths do
      new_line_paths[#new_line_paths + 1] = { line_paths[i][1], line_paths[i][2] }
    end

    line_paths = new_line_paths
    apply_indents_to_buffer(tree_buf, line_paths)
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

    apply_indents_to_buffer(tree_buf, line_paths)
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

  vim.keymap.set("n", "<Esc>", function()
    if vim.api.nvim_win_is_valid(tree_win) then vim.api.nvim_win_close(tree_win, true) end
    if vim.api.nvim_win_is_valid(preview_win) then vim.api.nvim_win_close(preview_win, true) end
  end, { buffer = tree_buf, silent = true })

  vim.keymap.set("n", "<CR>", function()
    local cursor_pos = vim.api.nvim_win_get_cursor(tree_win)
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
			if vim.api.nvim_win_is_valid(tree_win) then
				vim.api.nvim_win_close(tree_win, true)
				vim.api.nvim_win_close(preview_win, true)
			end
      vim.cmd("edit " .. path)
    end
  end, { buffer = tree_buf, silent = true })

  return tree_buf, tree_win, preview_buf, preview_win
end

return M

