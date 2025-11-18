local M = {}


function M.setup(opts)
	opts = opts or {}

	local window = require "navigator.window"
	local files = require "navigator.files"
	
	vim.keymap.set("n", "<leader>t", function()
		window.open_tree(files.get_files(vim.loop.cwd()))
	end)
end

return M
