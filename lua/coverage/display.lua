local utils = require("coverage.utils")

local M = {}

---@param cov_data CoverageData
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

---@param width_props table
---@param win_width number
---@param col integer
---@return ColPos | nil
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

---@param width_props table
---@param win_width number
M.calculate_width = function(width_props, win_width)
	local widths = {}
	for i, p in ipairs(width_props) do
		widths[i] = math.floor(p * win_width)
	end
	return widths
end

---@param width_props table
---@param specs table
---@param align table
---@param win_width number
---@return string | nil
M.format_display_string = function(width_props, specs, align, win_width)
	local str = ""

	if #width_props ~= #specs or #width_props ~= #align then
		return nil
	end

	local widths = M.calculate_width(width_props, win_width)

	for i, _ in ipairs(width_props) do
		str = str .. "%" .. align[i] .. widths[i] .. specs[i]
	end

	return str
end

---@param data CoverageData
---@param width number
---@param buf integer
---@return integer
M.write_functions = function(data, width, start_line, buf)
	local width_props = { 0.6, 0.2, 0.2 }
	local hfmt = M.format_display_string(width_props, { "s", "s", "s" }, { "-", "-", "-" }, width)
	if hfmt == nil then
		return -1
	end

	local fmt = M.format_display_string(width_props, { "s", "s", "d" }, { "-", "-", "-" }, width)
	if fmt == nil then
		return -1
	end

	local f = data.functions
	local lines = {}
	local max_str_len = 50

	for name, fcov in pairs(f) do
		local ok = "Covered"
		if fcov.count <= 0 then
			ok = "Uncovered"
		end
		local func_id = name
		func_id = #func_id > max_str_len and "..." .. func_id:sub(-max_str_len) or func_id

		local line =
			{ cov = fcov.count > 0, content = string.format(fmt, "|--->" .. func_id, ok, fcov.line), sort = fcov.line }

		table.insert(lines, line)
	end

	table.sort(lines, function(a, b)
		return a.sort < b.sort
	end)

	local write = {}

	table.insert(write, "")
	table.insert(write, string.format(hfmt, "Function", "Coverage", "Line Num"))

	for _, l in pairs(lines) do
		table.insert(write, l.content)
	end

	table.insert(write, "")

	vim.api.nvim_buf_set_lines(buf, start_line, start_line, false, write)

	local col = M.get_col_width(width_props, width, 2)
	M.colour_coverages(col, lines, buf, start_line + 1)

	return #write
end

---@param cov_data table<string, CoverageData>
---@param proj_path string
M.display_data = function(cov_data, proj_path)
	local origin_win = vim.api.nvim_get_current_win()

	local fw = utils.floating_window()
	local buf = fw.buf
	local win = fw.win
	local width = vim.api.nvim_win_get_width(win)

	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = true

	local align = { "-", "-" }
	local htypes = { "s", "s" }
	local types = { "s", "f" }

	local field_width_prop = { 0.6, 0.4 }

	local header_fmt = M.format_display_string(field_width_prop, htypes, align, width)
	if header_fmt == nil then
		return
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { string.format(header_fmt, "Source File", "Coverage") })

	local content_fmt = M.format_display_string(field_width_prop, types, align, width)
	if content_fmt == nil then
		return
	end

	local lines = {}
	local path_map = {}

	for _, v in pairs(cov_data) do
		local covered_lines, total_lines = M.analyse_lines(v)
		local cov = covered_lines / total_lines * 100
		local rel_path = utils.get_project_rel_path(v.path, proj_path .. "/")
		local line_content = string.format(content_fmt, rel_path, cov)

		table.insert(path_map, { path = rel_path, data = v })
		table.insert(lines, { sort = cov, cov = cov >= 60, content = line_content })
	end

	table.sort(lines, function(a, b)
		return a.sort > b.sort
	end)

	for _, c in pairs(lines) do
		utils.buf_append(buf, { c.content })
	end

	local selected = {}
	vim.keymap.set("n", "<CR>", function()
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
			if selected[line] then
				local num_lines = selected[line].num_lines
				vim.api.nvim_buf_set_lines(buf, line, line + num_lines, false, {})
				selected[line] = nil
			else
				for _, c in pairs(path_map) do
					if c.path == rpath then
						local num_lines = M.write_functions(c.data, width, line, buf)
						if num_lines > 0 then
							selected[line] = { start = line, num_lines = num_lines, path = c.path }
						end
					end
				end
			end
		end
	end, { buffer = buf })

	vim.keymap.set("n", "<Esc>", function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf })

	local cov_col = M.get_col_width(field_width_prop, width, 2)
	M.colour_coverages(cov_col, lines, buf, 0)
end

---@param pos ColPos | nil
---@param lines table<Line>
---@param buf integer
---@param start_line integer
M.colour_coverages = function(pos, lines, buf, start_line)
	if pos == nil then
		return
	end

	local ns = vim.api.nvim_create_namespace("coverage")
	vim.api.nvim_set_hl(0, "CoverageUncovered", { fg = "#ff5555" })
	vim.api.nvim_set_hl(0, "CoverageCovered", { fg = "#50fa7b" })

	for i, l in ipairs(lines) do
		local col = "CoverageUncovered"
		if l.cov then
			col = "CoverageCovered"
		end
		vim.hl.range(buf, ns, col, { i + start_line, pos.start_x }, { i + start_line, pos.end_x })
	end
end

return M
