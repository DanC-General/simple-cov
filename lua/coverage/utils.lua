local M = {}

--- Searches the fs upwards for a directory containing the expected path regex.
--- If the match is a file, returns the enclosing directory.
--- If the match is a directory, returns it.
--- If there are no matches, returns nil.
--- e.g. dotnet projects expect a .csproj file at the project root.
--- @param root_entry_re string
--- @return string | nil
M.project_root = function(root_entry_re)
	-- TODO: If multiple paths, check for best (or return all)
	local target = vim.fs.find(function(name)
		return name:match(root_entry_re)
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
		vim.notify("Failed to find an upper directory containing " .. root_entry_re)
		return nil
	end

	return project_dir
end

--- Checks if the expected coverage directory exists
--- for the project root. Returns the path to it or nil.
--- @param root_entry_re string
--- @return string | nil
M.coverage_dir = function(root_entry_re)
	local root = M.project_root(root_entry_re)

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

--- Checks if the expected coverage file exists
--- for the project root. Returns the path to it or nil.
--- @param root_entry_re string
--- @return string | nil
M.coverage_file = function(root_entry_re)
	local cd = M.coverage_dir(root_entry_re)

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

--- Create a new floating window, returns the window and buffer.
--- @return table
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

--- Returns the expected path to the coverage file, if the project root can be found.
--- Otherwise, returns nil.
--- Does not check file existence.
--- @param root_entry_re string
--- @return table | nil
M.coverage_file_loc = function(root_entry_re)
	local root = M.project_root(root_entry_re)

	if root == nil then
		vim.notify("Couldn't find project root for coverage.", vim.log.levels.WARN)
		return nil
	end

	return { dir = root .. "/coverage", fname = "lcov.info" }
end

--- Runs a command in a non-interactive floating window.
--- @param cmd table<string>
--- @param cmd_opts table
M.run_in_floating_term = function(cmd, cmd_opts)
	local fw = M.floating_window()
	local buf = fw.buf
	local win = fw.win

	vim.api.nvim_set_current_buf(buf)

	vim.api.nvim_win_set_config(win, {
		title = "$ " .. table.concat(cmd, " "),
		title_pos = "left",
	})

	vim.fn.jobstart(
		cmd,
		vim.tbl_extend("force", cmd_opts, {
			on_exit = function(_, code)
				vim.schedule(function()
					vim.notify(("Process (%s) exited with code %d"):format(table.concat(cmd), code))
				end)
			end,
			term = true,
		})
	)

	vim.keymap.set("n", "<CR>", function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf })

	vim.keymap.set("n", "<Esc>", function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf })

	vim.cmd("startinsert")
end

--- Writes content to the end of buf.
---@param content table<string>
---@param buf integer
M.buf_append = function(buf, content)
	local line_count = vim.api.nvim_buf_line_count(buf)
	vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, content)
end

--- Takes an absolute path and returns the path relative to the project directory containing 'root_entry_re'.
--- If 'path' is not in the project directory, it will be returned unaltered.
---@param path string
---@param proj_path string
---@return string
M.get_project_rel_path = function(path, proj_path)
	local rel_path, _ = string.gsub(path, proj_path, "")
	return rel_path
end

--- Takes a relative path and returns the path absolute to the project directory containing 'root_entry_re'.
--- If 'path' is not in the project directory, it will be returned unaltered.
---@param path string
---@param proj_path string
---@return string
M.get_project_abs_path = function(path, proj_path)
	local rel_path, _ = string.gsub(path, "^", proj_path)
	return rel_path
end

--- If str is longer than max_len, removes characters from the start
--- until it is the desired length, adds a '...' prefix, and returns it.
--- Otherwise, returns str. Max_len should be a vim window width.
--- @param str string
--- @param max_len integer
--- @return string
M.truncate_str_start = function(str, max_len)
	-- Account for added ... and a bit of buffer room.
	max_len = max_len - vim.fn.strdisplaywidth(".....")
	local text_width = vim.fn.strdisplaywidth(str)

	while vim.fn.strdisplaywidth(str) > max_len do
		local diff = vim.fn.strdisplaywidth(str) - max_len
		str = str:sub(diff + 1)
	end

	if text_width ~= vim.fn.strdisplaywidth(str) then
		str = "..." .. str
	end
	return str
end

return M
