local M = {}

local window = require "navigator.window"

function M.setup(opts)
	opts = opts or {}
	
	vim.keymap.set("n", "<leader>t", function()
		window.open_floating_window()
	end)
end

return M
