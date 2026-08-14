local M = {}

local config = require("coverage.config")
local defaults = require("coverage.filetypes.defaults")

M.show = function()
	defaults.show(config.opts.filetype.rust)
end

M.generate = function()
	defaults.generate(config.opts.filetype.rust)
end

---@cast M FiletypeHandler
return M
