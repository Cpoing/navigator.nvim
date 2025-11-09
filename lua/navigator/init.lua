local M = {}

local window = require "navigator.window"
local files = require "navigator.files"

function M.setup(opts)
	opts = opts or {}
	
	vim.keymap.set("n", "<leader>t", function()
		local files_list = files.get_files(vim.loop.cwd())
		window.open_floating_window(files_list)
	end)
end

return M
