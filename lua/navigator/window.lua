local M = {}

local tree = require("navigator.tree")

function M.open_tree(files)
  local sw = vim.o.columns
  local sh = vim.o.lines

  local width = math.floor(sw * 0.95)
  local height = math.floor(sh * 0.95)
  local row = math.floor((sh - height) / 2)
  local col = math.floor((sw - width) / 2)

  local left_width = math.floor(width * 0.35)
	local right_width = width - left_width

  local tree_buf = vim.api.nvim_create_buf(false, true)
  local tree_win = vim.api.nvim_open_win(tree_buf, true, {
    relative = "editor",
    width = left_width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  tree.setup(tree_buf, files)

	local preview_buf = vim.api.nvim_create_buf(false, true)
	local preview_win = vim.api.nvim_open_win(preview_buf, false, {
		relative = "editor",
		width = right_width,
		height = height,
		row = row,
		col = col + left_width + 2,
		style = "minimal",
		border = "rounded",
	})

	local last_previewed = nil

	vim.api.nvim_create_autocmd("CursorMoved", {
			buffer = tree_buf,
			callback = function()
					local node = tree.get_node_at_cursor(tree_win)
					if not node or node.is_dir then
						vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, {})
						last_previewed = nil
						return
					end

					if last_previewed == node.path then return end
					last_previewed = node.path

					local ok, lines = pcall(vim.fn.readfile, node.path)
					if not ok then
							lines = { "Failed to load file" }
					end

					vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)
					local ft = vim.filetype.match({ filename = node.path })
					vim.api.nvim_buf_set_option(preview_buf, "filetype", ft or "")
			end,
	})

	vim.o.cursorline = true

  vim.keymap.set("n", "<Esc>", function()
    if vim.api.nvim_win_is_valid(tree_win) then
      vim.api.nvim_win_close(tree_win, true)
    end
		if vim.api.nvim_win_is_valid(preview_win) then
			vim.api.nvim_win_close(preview_win, true)
		end
  end, { buffer = tree_buf })

  vim.keymap.set("n", "<CR>", function()
    local lnum = vim.api.nvim_win_get_cursor(tree_win)[1]
    local node = tree.get_node_at_line(lnum)
    if not node then return end

    if node.is_dir then
      tree.toggle(node)
      return
    end

		if vim.api.nvim_win_is_valid(tree_win) then
			vim.api.nvim_win_close(tree_win, true)
		end
		if vim.api.nvim_win_is_valid(preview_win) then
			vim.api.nvim_win_close(preview_win, true)
		end
    vim.cmd("edit " .. vim.fn.fnameescape(node.path))
  end, { buffer = tree_buf })

end

return M
