local M = {
	--- @type Config
	opts = {},
}
---@class Config
---@field filetype table
local defaults = {
	filetype = {
		rust = {
			root_entry = "target",
			generator_cmd = {
				"cargo",
				"llvm-cov",
				"--lcov",
				"--output-path",
				"${file}",
			},
		},
	},
}

function M.setup(user_opts)
	M.opts = vim.tbl_deep_extend("force", defaults, user_opts or {})
end

return M
