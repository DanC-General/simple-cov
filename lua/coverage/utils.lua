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

	if vim.fn.isdirectory(cd) ~= 1 then
		vim.notify("Failed to load coverage directory" .. cd .. ".", vim.log.levels.WARN)
		return nil
	end

	-- TODO: support other coverage ftypes
	local cf = cd .. "/lcov.info"

	local stat = vim.uv.fs_stat(cf)

	if stat and stat.type ~= "file" then
		vim.notify("Error loading coverage file" .. cf .. ".", vim.log.levels.WARN)
		return nil
	end

	return cf
end

M.floating_window = function()
	local buf = vim.api.nvim_create_buf(false, true)

	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)

	local col = math.floor((vim.o.columns - width) / 2)
	local row = math.floor((vim.o.lines - height) / 2)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		style = "minimal",
		border = "rounded",
	})

	return {
		buf = buf,
		win = win,
	}
end

M.coverage_file_loc = function(root_entry)
	local root = M.project_root(root_entry)

	if root == nil then
		vim.notify("Couldn't find project root for coverage.", vim.log.levels.WARN)
		return nil
	end

	return { dir = root .. "/coverage", fname = "lcov.info" }
end

M.run_in_floating_term = function(cmd, cmd_opts)
	local fw = M.floating_window()
	local buf = fw.buf
	local win = fw.win

	vim.api.nvim_set_current_buf(buf)

	vim.fn.termopen(
		cmd,
		vim.tbl_extend("force", cmd_opts, {
			on_exit = function(_, code)
				vim.schedule(function()
					vim.notify(("Process exited with code %d"):format(code))
				end)
			end,
		})
	)

	vim.cmd("startinsert")
end

---@param content table
M.buf_append = function(buf, content)
	local line_count = vim.api.nvim_buf_line_count(buf)
	vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, content)
end

--- Takes an absolute path and returns the path relative to the project directory containing 'entry_re'.
--- If 'path' is not in the project directory, it will be returned unaltered.
---@param path string
---@param proj_path string
---@return string
M.get_project_rel_path = function(path, proj_path)
	local rel_path, c = string.gsub(path, proj_path, "")
	return rel_path
end

--- Takes a relative path and returns the path absolute to the project directory containing 'entry_re'.
--- If 'path' is not in the project directory, it will be returned unaltered.
---@param path string
---@param proj_path string
---@return string
M.get_project_abs_path = function(path, proj_path)
	local rel_path, c = string.gsub(path, "^", proj_path)
	return rel_path
end
return M
