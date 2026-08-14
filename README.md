# simple-cov

Neovim plugin for test coverage. Works with a project-oriented approach to coverage, where we assume that an nvim session can contain multiple self-contained software projects.

Currently supports generating and displaying coverage.

Language Support: 
    - rust 
    - c#

Coverage Filetype Support: 
    - lcov

## Installation

By default no keymaps are implemented, but the functions are exposed.

Using Lazy:
```lua
return {
	"DanC-General/simple-cov",
	config = function()
		require("coverage").setup({})
		vim.keymap.set("n", "<leader>as", require("coverage").show)
		vim.keymap.set("n", "<leader>ag", require("coverage").generate)
	end,
}
```

## Usage 

Open a file in the project you want to see the coverage for. 
If you do not already have a coverage file, run the generate function to create one. 

Run the show function to display a coverage summary for the project. 
In the display, hit 'Enter' on a file to show function coverage, and hit 'Enter' on a function line to jump to that function.

## Configuration 

Configuring the plugin for other languages should be straightforward. 
Create a new file in the filetypes/ directory, named with the appropriate vim ft extension, and implement the required methods. 
The provided rust and cs files show examples for the default implementation.

The following plugin configuration options are supported: 
```lua
local defaults = {
    --- Filetype handlers
	filetype = {
		cs = {
            --- Regex for a fs entry indicating we have found the root folder for the project. 
			root_entry = ".*%.slnx",
            --- Command run to generate the config file - ${path} is the expected plugin path to the coverage file. The plugin expands some variables (sub_vars in filetypes/default.lua) before shell expansion.
			generator_cmd = {
				"dotnet",
				"test",
				"/p:CollectCoverage=true",
				"/p:CoverletOutputFormat=lcov",
				"/p:CoverletOutput=${path}",
			},
		},
		rust = {
			root_entry = "target",
			generator_cmd = {
				"cargo",
				"llvm-cov",
				"--lcov",
				"--output-path",
				"${path}",
			},
		},
	},
}
```
