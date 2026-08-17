local utils = require("coverage.utils")

local M = {}

--- Builds a format string for the given paramaters.
--- For example:
--- 	format_display_string({0.6,0.4}, {"s","d"}, {"","-"}, 100)
--- 	would return  "%60s%-40d"
--- @param width_props table<number>
--- @param specs table<string>
--- @param align table<string>
--- @param win_width number
--- @return string | nil
M.format_display_string = function(width_props, specs, align, win_width)
	if #width_props ~= #specs or #width_props ~= #align then
		return nil
	end

	local str = ""
	local widths = M.calculate_width(width_props, win_width)

	for i, _ in ipairs(width_props) do
		str = str .. "%" .. align[i] .. widths[i] .. specs[i]
	end

	return str
end

--- Given a list of proportional desired widths for columns and
--- the width of the window, calculates the actual width for each desired column for that window.
--- @param width_props table<number>
--- @param win_width number
--- @return table<integer>
M.calculate_width = function(width_props, win_width)
	local widths = {}
	for i, p in ipairs(width_props) do
		widths[i] = math.floor(p * win_width)
	end
	return widths
end

--- Finds the actual width of a column from proportional column widths,
--- the width of the window and the column number of interest.
--- @param width_props table
--- @param win_width number
--- @param col integer
--- @return ColPos | nil
M.get_col_width = function(width_props, win_width, col)
	local widths = M.calculate_width(width_props, win_width)

	if col <= 0 or col > #widths then
		return nil
	end

	local start_x = 0
	local end_x = 0

	for i, _ in ipairs(widths) do
		start_x = end_x
		end_x = start_x + widths[i]
		if col == i then
			return {
				start_x = start_x,
				end_x = end_x,
			}
		end
	end

	return nil
end

--- Takes in a set of Lines, and conditionally colours the given buf based on the line.cov bool.
--- Starts at line start_line in buf, and will colour the next #lines lines.
--- The column (x positions) that are coloured are given by the pos coordinates.
--- @param pos? ColPos
--- @param lines table<Line>
--- @param buf integer
--- @param start_line integer
--- @param text_col_func fun(text:string): boolean?
M.colour_columns = function(pos, lines, buf, start_line, text_col_func)
	if pos == nil then
		return
	end

	local ns = vim.api.nvim_create_namespace("coverage")

	vim.api.nvim_set_hl(0, "Uncovered", { fg = "#ff5555" })
	vim.api.nvim_set_hl(0, "Covered", { fg = "#50fa7b" })

	for i, _ in ipairs(lines) do
		local row = i + start_line

		if text_col_func then
			local text = vim.api.nvim_buf_get_text(0, row, pos.start_x, row, pos.end_x, {})[1]

			local result = text_col_func(text)
			if result ~= nil then
				local colour = result and "Covered" or "Uncovered"
				vim.hl.range(buf, ns, colour, { row, pos.start_x }, { row, pos.end_x })
			end
		end
	end
end

--- Analyses a CoverageData object to find the number of covered
--- lines and the total number of lines.
--- @param cov_data CoverageData
--- @return integer, integer
M.analyse_lines = function(cov_data)
	local lines = cov_data.lines
	local total = 0
	local covered = 0

	for _, c in pairs(lines) do
		total = total + 1
		if c ~= 0 then
			covered = covered + 1
		end
	end
	return covered, total
end

---@param summary Summary
---@return number | nil
M.analyse_summary = function(summary)
	local prop = summary.hits / summary.total

	-- NaN check
	if prop ~= prop then
		return nil
	end

	return prop * 100
end

--- Analyses the summaries section of a CoverageData object,
--- and appends the results to buf. Populates path_map
--- with the relative paths to the relevant object.
--- @param data CoverageData
--- @param proj_path string
--- @param win_width number
--- @param buf integer
--- @param path_map table
M.write_summaries = function(data, proj_path, win_width, buf, path_map)
	local align = { "-", "-", "-", "-", "-" }
	local htypes = { "s", "s", "s", "s", "s" }
	local types = { "s", "f", "f", "f", "f" }
	local field_width_prop = { 0.4, 0.1, 0.1, 0.1, 0.2 }
	local lines = {}

	local header_fmt = M.format_display_string(field_width_prop, htypes, align, win_width)
	if header_fmt == nil then
		return
	end

	vim.api.nvim_buf_set_lines(
		buf,
		0,
		-1,
		false,
		{ string.format(header_fmt, "Source File", "Line", "Branch", "Function", "Total") }
	)

	for _, v in pairs(data) do
		local cur_types = vim.deepcopy(types)
		local cov = {
			line = { value = M.analyse_summary(v.summaries.lines), col = 2 },
			func = { value = M.analyse_summary(v.summaries.functions), col = 4 },
			branch = { value = M.analyse_summary(v.summaries.branches), col = 3 },
		}

		for _, c in pairs(cov) do
			if not c.value then
				c.value = "?"
				cur_types[c.col] = "s"
			end
		end

		local total
		if type(cov.line.value) == "number" and type(cov.func.value) == "number" then
			total = (cov.line.value + cov.func.value) / 2
		else
			cur_types[5] = "s'"
			total = "?"
		end

		local content_fmt = M.format_display_string(field_width_prop, cur_types, align, win_width)
		if content_fmt == nil then
			vim.notify("Invalid display format string.")
			return
		end

		local fpath_width = math.floor(field_width_prop[1] * win_width)
		local rel_path = utils.truncate_str_start(utils.get_project_rel_path(v.path, proj_path .. "/"), fpath_width)
		local line_content =
			string.format(content_fmt, rel_path, cov.line.value, cov.branch.value, cov.func.value, total)

		table.insert(path_map, { path = rel_path, data = v })
		table.insert(lines, { sort = total, content = line_content })
	end

	table.sort(lines, function(a, b)
		return a.sort > b.sort
	end)

	for _, c in pairs(lines) do
		utils.buf_append(buf, { c.content })
	end

	local cov_cols = { 2, 3, 4, 5 }
	for _, col in ipairs(cov_cols) do
		local cov_col = M.get_col_width(field_width_prop, win_width, col)
		M.colour_columns(cov_col, lines, buf, 0, function(text)
			if not tonumber(text) then
				return nil
			end

			return tonumber(text) > 60
		end)
	end
end

--- Analyses the function section of a CoverageData object, and writes the
--- results to the correct position in the given buffer. Returns the number
--- of lines that were written, or -1 on error.
--- @param data CoverageData
--- @param win_width number
--- @param start_line integer
--- @param buf integer
--- @return integer
M.write_functions = function(data, win_width, start_line, buf)
	local width_props = { 0.6, 0.2, 0.2 }
	local f = data.functions
	local lines = {}
	local write = {}
	local max_str_len = 50

	local hfmt = M.format_display_string(width_props, { "s", "s", "s" }, { "-", "-", "-" }, win_width)
	if hfmt == nil then
		return -1
	end

	local fmt = M.format_display_string(width_props, { "s", "s", "d" }, { "-", "-", "-" }, win_width)
	if fmt == nil then
		return -1
	end

	for name, fcov in pairs(f) do
		local ok = "Covered"
		local func_id = utils.truncate_str_start(name, max_str_len)

		if fcov.count <= 0 then
			ok = "Uncovered"
		end

		local line = {
			cov = fcov.count > 0,
			content = string.format(fmt, "|--->" .. func_id, ok, fcov.line),
			sort = fcov.line,
		}

		table.insert(lines, line)
	end

	table.sort(lines, function(a, b)
		return a.sort < b.sort
	end)

	table.insert(write, "")
	table.insert(write, string.format(hfmt, "Function", "Coverage", "Line Num"))

	for _, l in pairs(lines) do
		table.insert(write, l.content)
	end

	table.insert(write, "")

	vim.api.nvim_buf_set_lines(buf, start_line, start_line, false, write)

	local col = M.get_col_width(width_props, win_width, 2)
	M.colour_columns(col, lines, buf, start_line + 1, function(text)
		return text:gsub("%s+", "") == "Covered"
	end)

	return #write
end

--- Analyses the branch section of a CoverageData object, and writes the
--- results to the correct position in the given buffer. Returns the number
--- of lines that were written, or -1 on error.
--- @param data CoverageData
--- @param win_width number
--- @param start_line integer
--- @param buf integer
--- @return integer
M.write_branches = function(data, win_width, start_line, buf)
	local width_props = { 0.6, 0.2, 0.2 }
	local b = data.branches
	local lines = {}
	local write = {}

	local hfmt = M.format_display_string(width_props, { "s", "s", "s" }, { "-", "-", "-" }, win_width)
	if hfmt == nil then
		return -1
	end

	local fmt = M.format_display_string(width_props, { "s", "s", "d" }, { "-", "-", "-" }, win_width)
	if fmt == nil then
		return -1
	end

	for _, bcov in pairs(b) do
		local line = {
			content = string.format(fmt, "|--->" .. bcov.block .. "-" .. bcov.branch, ok, bcov.line),
			sort = bcov.line,
		}

		table.insert(lines, line)
	end

	table.sort(lines, function(x, y)
		return x.sort < y.sort
	end)

	table.insert(write, "")

	if #lines > 0 then
		table.insert(write, string.format(hfmt, "Branch ID", "Coverage", "Line Num"))

		for _, l in pairs(lines) do
			table.insert(write, l.content)
		end
	else
		table.insert(write, "No branch information.")
	end

	vim.api.nvim_buf_set_lines(buf, start_line, start_line, false, write)

	if #lines > 0 then
		local col = M.get_col_width(width_props, win_width, 2)
		M.colour_columns(col, lines, buf, start_line + 1, function(text)
			return tonumber(text) and tonumber(text) > 0
		end)
	end

	return #write
end

--- Handler for <Enter> events within win. Currently:
--- 	1. On file, shows associated functions
--- 	2. On function, jumps to the relevant location.
--- @param win integer
--- @param buf integer
--- @param origin_win integer
--- @param proj_path string
--- @param selected table
--- @param path_map table
--- @param win_width integer
M.handle_enter = function(win, buf, origin_win, proj_path, selected, path_map, win_width)
	local line = vim.api.nvim_win_get_cursor(win)[1]
	local text = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1]
	local rpath = text:match("%S+")

	if rpath:match("--->") then
		local line_num = tonumber(text:match("(%S+)%s+$"))

		for _, c in pairs(selected) do
			if c.start <= line and c.start + c.num_lines >= line then
				local abs = utils.get_project_abs_path(c.path, proj_path .. "/")
				vim.api.nvim_win_close(win, true)
				vim.api.nvim_set_current_win(origin_win)
				vim.cmd.edit(abs)
				vim.api.nvim_win_set_cursor(origin_win, { line_num, 0 })
			end
		end
	else
		if selected[rpath] then
			local num_lines = selected[rpath].num_lines
			vim.api.nvim_buf_set_lines(buf, line, line + num_lines, false, {})
			selected[rpath] = nil
		else
			for _, c in pairs(path_map) do
				if c.path == rpath then
					local num_lines = M.write_functions(c.data, win_width, line, buf)
						+ M.write_branches(c.data, win_width, line, buf)
					if num_lines > 0 then
						selected[rpath] = { start = line, num_lines = num_lines, path = c.path }
					end
				end
			end
		end
	end
end

--- Shows the coverage data in a floating window.
--- @param cov_data table<string, CoverageData>
--- @param proj_path string
M.display_data = function(cov_data, proj_path)
	local origin_win = vim.api.nvim_get_current_win()

	local fw = utils.floating_window()
	local buf = fw.buf
	local win = fw.win
	local width = vim.api.nvim_win_get_width(win)
	local selected = {}
	local path_map = {}

	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = true

	M.write_summaries(cov_data, proj_path, width, buf, path_map)

	vim.keymap.set("n", "<CR>", function()
		M.handle_enter(win, buf, origin_win, proj_path, selected, path_map, width)
	end, { buffer = buf })

	vim.keymap.set("n", "<Esc>", function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf })
end

return M
