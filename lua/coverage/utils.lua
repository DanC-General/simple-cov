local M = {}

-- Searches the fs upwards for a directory containing the expected path regex.
-- If the match is a file, returns the enclosing directory.
-- If the match is a directory, returns it.
-- e.g. dotnet projects expect a .csproj file at the project root.
M.project_root = function(entry_re)
	-- TODO: If multiple paths, check for best (or return all)
	local target = vim.fs.find(function(name)
		return name:match(entry_re)
	end, {
		upward = true,
		path = vim.api.nvim_buf_get_name(0),
	})[1]

	local project_dir

	if target then
		if vim.fn.isdirectory(target) == 1 then
			project_dir = vim.fs.dirname(target)
		elseif vim.fn.filereadable(target) == 1 then
			project_dir = vim.fs.dirname(target)
		else
			vim.notify("Target exists but is unknown:", target)
			return nil
		end
	else
		vim.notify("Failed to find an upper directory containing " .. entry_re)
		return nil
	end

	return project_dir
end

M.coverage_dir = function(root_entry)
	local root = M.project_root(root_entry)

	if root == nil then
		vim.notify("Couldn't find project root for coverage.", vim.log.levels.WARN)
		return nil
	end

	local coverage_dir = root .. "/coverage"

	if vim.fn.isdirectory(coverage_dir) ~= 1 then
		vim.notify("Failed to load coverage directory.", vim.log.levels.WARN)
		return nil
	end
	return coverage_dir
end

M.coverage_file = function(root_entry)
	local cd = M.coverage_dir(root_entry)

	if cd == nil then
		return
	end

	-- TODO: support other coverage ftypes
	local cf = cd .. "/lcov.info"

	if vim.fn.isdirectory(cf) ~= 1 then
		vim.notify("Failed to load coverage file" .. cf .. ".", vim.log.levels.WARN)
		return nil
	end

	return cf
end

M.coverage_file_loc = function(root_entry)
	local root = M.project_root(root_entry)

	if root == nil then
		vim.notify("Couldn't find project root for coverage.", vim.log.levels.WARN)
		return nil
	end

	return root .. "/coverage" .. "/lcov.info"
end

return M
