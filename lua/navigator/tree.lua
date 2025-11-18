local M = {}

local files_api = require("navigator.files")

local tree_buf = nil
local cwd = nil

local nodes = {}
local expanded = {}

local function join_path(a, b)
  if a:sub(-1) == "/" then a = a:sub(1, -2) end
  if b:sub(1, 1) == "/" then b = b:sub(2) end
  return a .. "/" .. b
end

local function is_dir(path)
  local stat = vim.loop.fs_stat(path)
  return stat and stat.type == "directory"
end

local function render()
  local lines = {}

  for i, node in ipairs(nodes) do
    local indent = string.rep("  ", node.depth)
    local name = node.path:match("[^/]+$")
    lines[i] = indent .. name
  end

  vim.api.nvim_buf_set_lines(tree_buf, 0, -1, false, lines)

  for i, node in ipairs(nodes) do
    if node.is_dir then
      pcall(vim.api.nvim_buf_add_highlight, tree_buf, 0, "Directory", i - 1, 0, -1)
    end
  end
end

local function rebuild_node_list(base, depth)
  local items = files_api.get_files(base)
  local ret = {}

  for _, name in ipairs(items) do
    local p = join_path(base, name)
    table.insert(ret, {
      path = p,
      depth = depth,
      is_dir = is_dir(p),
    })
  end

  return ret
end

function M.get_node_at_line(line)
  return nodes[line]
end

local function expand(idx)
  local node = nodes[idx]
  if not node or not node.is_dir then return end

  expanded[node.path] = true
  local children = rebuild_node_list(node.path, node.depth + 1)

  local new = {}

  for i = 1, idx do table.insert(new, nodes[i]) end
  for _, c in ipairs(children) do table.insert(new, c) end
  for i = idx + 1, #nodes do table.insert(new, nodes[i]) end

  nodes = new
  render()
end

local function collapse(idx)
  local node = nodes[idx]
  if not node or not node.is_dir then return end

  expanded[node.path] = nil

  local new = {}

  for i = 1, idx do table.insert(new, nodes[i]) end

  local prefix = node.path
  local j = idx + 1
  while j <= #nodes and nodes[j].path:sub(1, #prefix) == prefix do
    j = j + 1
  end

  for i = j, #nodes do table.insert(new, nodes[i]) end

  nodes = new
  render()
end

function M.toggle(node)
  local idx
  for i, n in ipairs(nodes) do if n == node then idx = i break end end
  if not idx then return end

  if expanded[node.path] then
    collapse(idx)
  else
    expand(idx)
  end
end

function M.setup(buf, file_list)
  tree_buf = buf
  cwd = vim.loop.cwd()

  nodes = {}

  for _, name in ipairs(file_list) do
    local p = join_path(cwd, name)
    table.insert(nodes, {
      path = p,
      depth = 0,
      is_dir = is_dir(p),
    })
  end

  render()
end

return M
