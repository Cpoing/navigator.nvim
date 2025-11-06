local M = {}

function M.setup(opts)
	opts = opts or {}
	
	vim.keymap.set("n", "<leader>t", function()
		if opts.name then
			print("hello, " .. opts.name)
		else
			print("hello")
		end
	end)
end

return M
