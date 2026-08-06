local M = {}

---@return table<string, CoverageData>
M.parse_lcov = function(lcov_file)
	local files = {}
	local current

	for line in io.lines(lcov_file) do
		if line:match("^SF:") then
			current = {
				path = line:sub(4),
				lines = {},
				functions = {},
				branches = {},
			}
			files[current.path] = current
		elseif line:match("^DA:") then
			local lnum, count = line:match("^DA:(%d+),(%d+)")
			current.lines[tonumber(lnum)] = tonumber(count)
		elseif line:match("^FN:") then
			local lnum, name = line:match("^FN:(%d+),(.+)")
			current.functions[name] = {
				line = tonumber(lnum),
			}
		elseif line:match("^FNDA:") then
			local count, name = line:match("^FNDA:(%d+),(.+)")
			current.functions[name].count = tonumber(count)
		elseif line:match("^BRDA:") then
			local line_no, block, branch, taken = line:match("^BRDA:(%d+),(%d+),(%d+),([%d-]+)")

			table.insert(current.branches, {
				line = tonumber(line_no),
				block = tonumber(block),
				branch = tonumber(branch),
				taken = taken == "-" and nil or tonumber(taken),
			})
		elseif line == "end_of_record" then
			current = nil
		end
	end

	return files
end

return M
