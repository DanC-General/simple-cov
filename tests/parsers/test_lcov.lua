local parser = require("coverage.parsers.lcov")

local T = MiniTest.new_set()

T["Math operations"] = function()
	MiniTest.expect.equality(1 + 1, 2)
end

T["String matching"] = function()
	local target = "Neovim text editor"
	MiniTest.expect.match(target, "text")
end

return T
