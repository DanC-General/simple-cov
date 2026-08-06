local parser = require("coverage.parsers.lcov")

local T = MiniTest.new_set()

T["Load lcov file"] = function()
	local current_file = debug.getinfo(1, "S").source:sub(2)
	local current_dir = vim.fs.dirname(current_file)
	local test_lcov = current_dir .. "/lcov.info"

	local results = parser.parse_lcov(test_lcov)
	vim.print(results)
end

T["Math operations"] = function()
	MiniTest.expect.equality(1 + 1, 2)
end

return T
