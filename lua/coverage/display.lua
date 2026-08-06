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

---@param widths table
---@param col integer
---@return ColPos | nil
M.get_col_width = function(widths, col)
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

---@param widths table
---@param specs table
---@param align table
---@return string | nil
M.format_display_string = function(widths, specs, align)
	local str = ""

	if #widths ~= #specs or #widths ~= #align then
		return nil
	end

	for i, _ in ipairs(widths) do
		str = str .. "%" .. align[i] .. widths[i] .. specs[i]
	end

	return str
end

---@param cov_data table<string, CoverageData>
---@param proj_path string
M.display_data = function(cov_data, proj_path)
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
	local widths = {}

	for i, p in ipairs(field_width_prop) do
		widths[i] = math.floor(p * width)
	end

	local header_fmt = M.format_display_string(widths, htypes, align)
	if header_fmt == nil then
		return
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { string.format(header_fmt, "Source File", "Coverage") })

	local content_fmt = M.format_display_string(widths, types, align)
	if content_fmt == nil then
		return
	end

	local lines = {}

	for k, v in pairs(cov_data) do
		vim.notify(v.path)
		local covered_lines, total_lines = M.analyse_lines(v)

		local cov = covered_lines / total_lines * 100
		local line_content = string.format(content_fmt, utils.get_project_rel_path(v.path, proj_path .. "/"), cov)
		table.insert(lines, { cov = cov, content = line_content })
	end

	table.sort(lines, function(a, b)
		return a.cov > b.cov
	end)

	for _, c in pairs(lines) do
		utils.buf_append(buf, { c.content })
	end

	local cov_col = M.get_col_width(widths, 2)
	M.colour_coverages(cov_col, lines, buf)
end

---@param pos ColPos | nil
---@param lines table<Line>
M.colour_coverages = function(pos, lines, buf)
	if pos == nil then
		return
	end

	local ns = vim.api.nvim_create_namespace("coverage")
	vim.api.nvim_set_hl(0, "CoverageUncovered", { fg = "#ff5555" })
	vim.api.nvim_set_hl(0, "CoverageCovered", { fg = "#50fa7b" })

	for i, l in ipairs(lines) do
		local col = "CoverageUncovered"
		if l.cov >= 60 then
			col = "CoverageCovered"
		end
		vim.hl.range(buf, ns, col, { i, pos.start_x }, { i, pos.end_x })
	end
end

return M
