local M = {}
local file_utils = require("navigator.files")

function M.open_floating_window(files)
    local buf = vim.api.nvim_create_buf(false, true)
    local width = math.floor(vim.o.columns * 1)
    local height = math.floor(vim.o.lines * 1)
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

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, files)

    local expanded_dirs = {}
    local line_paths = {}
    local cwd = vim.loop.cwd()

		local function join_path(a, b)
				if a:sub(-1) == "/" then
						a = a:sub(1, -2)
				end
				if b:sub(1,1) == "/" then
						b = b:sub(2)
				end
				return a .. "/" .. b
		end

    for i, name in ipairs(files) do
        if name:sub(-1) == "/" then
            vim.api.nvim_buf_add_highlight(buf, 0, "Directory", i-1, 0, -1)
        end
        line_paths[i-1] = join_path(cwd, name)
    end

		local function insert_files_below(cursor_line, files, parent_path)
				local start_line = cursor_line + 1
				vim.api.nvim_buf_set_lines(buf, start_line, start_line, false, files)

				local new_line_paths = {}
				for i = 0, #line_paths do
						if i < start_line then
								new_line_paths[i] = line_paths[i]
						else
								new_line_paths[i + #files] = line_paths[i]
						end
				end
				line_paths = new_line_paths

				for i, name in ipairs(files) do
						if name:sub(-1) == "/" then
								vim.api.nvim_buf_add_highlight(buf, 0, "Directory", start_line + i - 1, 0, -1)
						end
						line_paths[start_line + i - 1] = join_path(parent_path, name)
				end
		end

		local function collapse_dir(cursor_line, files_inserted)
				local start = cursor_line + 1
				local finish = start + #files_inserted
				vim.api.nvim_buf_set_lines(buf, start, finish, false, {})

				local new_line_paths = {}
				for i = 0, #line_paths do
						if i < start then
								new_line_paths[i] = line_paths[i]
						elseif i >= finish then
								new_line_paths[i - #files_inserted] = line_paths[i]
						end
				end
				line_paths = new_line_paths

				expanded_dirs[cursor_line] = nil
		end


    vim.keymap.set("n", "<Esc>", function()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end, { buffer = buf, silent = true })

    vim.keymap.set("n", "<CR>", function()
        local cursor_pos = vim.api.nvim_win_get_cursor(0)
        local cursor_line = cursor_pos[1] - 1
        local path = line_paths[cursor_line]
        if not path then return end

        if vim.fn.isdirectory(path) ~= 0 then
            if expanded_dirs[cursor_line] then
                collapse_dir(cursor_line, expanded_dirs[cursor_line])
                expanded_dirs[cursor_line] = nil
            else
                local new_files = file_utils.get_files(path)
                insert_files_below(cursor_line, new_files, path)
                expanded_dirs[cursor_line] = new_files
            end
        else
						vim.api.nvim_win_close(win, true)
            vim.api.nvim_command("edit " .. path)
        end
    end, { buffer = buf, silent = true })

    return buf, win
end

return M

