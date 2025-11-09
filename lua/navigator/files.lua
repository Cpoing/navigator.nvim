local M = {}

function M.get_files(dir)
	local uv = vim.uv
	local files = {}

	local handle = uv.fs_scandir(dir)

	if handle then
		while true do
			local name, type = uv.fs_scandir_next(handle)
			if not name then break end
			if type == "directory" then
				name = name .. "/"
			end
			table.insert(files, name)
		end
	end
	
	return files
end

return M
