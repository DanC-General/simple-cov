local M = {}

local config = require("coverage.config")

M.show = function()
	local ft = vim.bo.filetype

	local ok, handler = pcall(require, "coverage.filetypes." .. ft)

	if not ok then
		return
	end

	handler.show()
end

M.generate = function()
	local ft = vim.bo.filetype

	local ok, handler = pcall(require, "coverage.filetypes." .. ft)

	if not ok then
		return
	end

	handler.generate()
end

---@param opts Config
M.setup = function(opts)
	config.setup(opts)
end
return M
