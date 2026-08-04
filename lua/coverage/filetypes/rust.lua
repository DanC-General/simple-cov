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
	local cfl = utils.coverage_file_loc(config.opts.filetype.rust.root_entry)

	if cfl == nil then
		return
	end

	local cov_path = cfl.dir .. "/" .. cfl.fname

	if not vim.fn.executable(gen_cmd[1]) then
		vim.notify("Can't run generator command " .. gen_cmd[1] .. " - not installed.", vim.log.levels.WARN)
		return
	end

	--- Allow command substitution in the generator_cmd string: "${x}" will be replaced with sub_vars.x
	local sub_vars = {
		file = cov_path,
	}

	for i, arg in ipairs(gen_cmd) do
		gen_cmd[i] = arg:gsub("%${(%w+)}", sub_vars)
	end

	local cmd_dir = utils.project_root(config.opts.filetype.rust.root_entry)
	if cmd_dir == nil then
		return
	end

	if vim.fn.isdirectory(cfl.dir) == 0 then
		vim.fn.mkdir(cfl.dir, "p")
	end

	local result = utils.run_in_floating_term(gen_cmd, { cwd = cmd_dir })
	-- local result = vim.system(gen_cmd, { cwd = cmd_dir }):wait()
	-- print(vim.inspect(result))
end

---@cast M FiletypeHandler
return M
