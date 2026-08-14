---@class FiletypeHandler
---@field show fun()
---@field generate fun()

---@class FunctionCoverage
---@field line integer
---@field count? integer

---@class BranchCoverage
---@field line integer
---@field block integer
---@field branch integer
---@field taken? integer

---@class CoverageData
---@field path string
---line_num, count
---@field lines table<integer, integer>
---@field functions table<string, FunctionCoverage>
---@field branches BranchCoverage[]

---@class ColPos
---@field start_x integer
---@field end_x integer

---@class Line
---@field cov boolean
---@field sort any
---@field content string

---@class FiletypeConfig
---@field root_entry string
---@field generator_cmd string[]

---@class Config
---@field filetype table<string, FiletypeConfig>
