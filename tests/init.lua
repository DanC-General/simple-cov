local test_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
local root = vim.fn.fnamemodify(test_dir, ":h")

vim.opt.runtimepath:prepend(root)

require("mini.test").setup({})
