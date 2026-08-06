local M = {}

local utils = require("coverage.utils")
local config = require("coverage.config")
local lcov = require("coverage.parsers.lcov")
local display = require("coverage.display")

M.load = function()
	local f = utils.coverage_file(config.opts.filetype.rust.root_entry)

	if f == nil then
		return
	end
	vim.notify(f)
end

M.show = function()
	local project_root = utils.project_root(config.opts.filetype.rust.root_entry)
	local cov_file = utils.coverage_file(config.opts.filetype.rust.root_entry)

	if cov_file == nil or project_root == nil then
		vim.notify("Couldn't find coverage file in 'show()'.")
		return
	end

	local cov_data = lcov.parse_lcov(cov_file)
	display.display_data(cov_data, project_root)
end

M.generate = function()
	vim.notify("Generating...")
	local gen_cmd = vim.deepcopy(config.opts.filetype.rust.generator_cmd)
	local cfl = utils.coverage_file_loc(config.opts.filetype.rust.root_entry)

	if cfl == nil then
		vim.notify("Couldn't find coverage file.")
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
		vim.notify("Couldn't find project root directory.")
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
