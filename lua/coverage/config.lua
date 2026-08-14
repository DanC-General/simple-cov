---@type Config
local defaults = {
	filetype = {
		cs = {
			root_entry = ".*%.slnx",
			generator_cmd = {
				"dotnet",
				"test",
				"/p:CollectCoverage=true",
				"/p:CoverletOutputFormat=lcov",
				"/p:CoverletOutput=${path}",
			},
		},
		rust = {
			root_entry = "target",
			generator_cmd = {
				"cargo",
				"llvm-cov",
				"--lcov",
				"--output-path",
				"${path}",
			},
		},
	},
}

local M = {
	---@type Config
	opts = defaults,
}

---@param user_opts UserConfig?
function M.setup(user_opts)
	if user_opts ~= nil then
		M.opts = vim.tbl_deep_extend("force", M.opts, user_opts)
	end
end

return M
