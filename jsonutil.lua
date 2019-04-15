--- JsonUtil
-- Provides utility functions for interacting with JSON
-- @Author: Brodur
-- @Version: 1.0
local json = require("json")
local fs = require("filesystem")
local io = require("io")
local ju = {}

--- Load Json
-- Loads the JSON database from file
-- @param dir  The directory where the database is located.
-- @return The parsed JSON table.
function ju.load(dir)
  str = ""
  for line in io.lines(dir) do str = str .. line end
  return json.parse(str)
end

--- Save Json
-- Save the contents of given table to JSON file.
-- @param tbl  The table to save.
-- @param dir  Where to save the table.
function ju.save(tbl, dir)
  file = io.open(dir, "w")
  file:write(json.stringify(tbl))
  file:close()
end

return ju