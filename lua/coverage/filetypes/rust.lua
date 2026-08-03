local M = {}

local utils = require("coverage.utils")
local config = require("coverage.config")

function M.load()
	local f = utils.coverage_file(config.opts.filetype.rust.root_entry)

	if f == nil then
		return
	end
	vim.notify(f)
end
M.show = function() end
M.generate = function()
	local gen_cmd = vim.deepcopy(config.opts.filetype.rust.generator_cmd)
	local f = utils.coverage_file_loc(config.opts.filetype.rust.root_entry)

	if not vim.fn.executable(gen_cmd[1]) then
		vim.notify("Can't run generator command " .. gen_cmd[1] .. " - not installed.", vim.log.levels.WARN)
		return
	end

	--- Allow command substitution in the generator_cmd string: "${x}" will be replaced with sub_vars.x
	local sub_vars = {
		file = f,
	}

	for i, arg in ipairs(gen_cmd) do
		gen_cmd[i] = arg:gsub("%${(%w+)}", sub_vars)
	end

	local cmd_dir = utils.project_root(config.opts.filetype.rust.root_entry)
	if cmd_dir == nil then
		return
	end

	local result = vim.system(gen_cmd, { cwd = cmd_dir }):wait()
	print(vim.inspect(result))
end

---@cast M FiletypeHandler
return M
