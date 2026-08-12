local M = {
	--- @type Config
	opts = {},
}
---@class Config
---@field filetype table
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

function M.setup(user_opts)
	M.opts = vim.tbl_deep_extend("force", defaults, user_opts or {})
end

return M
