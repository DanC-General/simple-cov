---@class FiletypeHandler
---@field show fun()
---@field load fun()
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
---@field lines table<integer, integer> -- line number -> hit count
---@field functions table<string, FunctionCoverage>
---@field branches BranchCoverage[]

---@class ColPos
---@field start_x integer
---@field end_x integer

---@class Line
---@field cov boolean
---@field sort any
---@field content string
---
---@class FiletypeConfig
---@field root_entry string
---@field generator_cmd table<string>
