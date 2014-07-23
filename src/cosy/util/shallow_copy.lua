-- Shallow Copy
-- ============

-- This `shallow_copy` function performs a shallow copy of a table.
-- If its parameter is `nil`, it returns an empty table.
--
-- __Trick:__ This function contains two implementations of the shallow
-- copy: one for Lua 5.2 using `table.(un)pack`, the other one for previous
-- Lua versions, performing a table copy through iteration. The Lua 5.2
-- version is more efficient.
--

local raw = require "cosy.util.raw"

local shallow_copy

if table.pack and table.unpack then -- Lua 5.2
  shallow_copy = function (data)
    if type (data) ~= "table" then
      return data
    else
      data = raw (data)
      local result = table.pack (table.unpack (data))
      result.n = nil
      return result
    end
  end
else
  shallow_copy = function (data)
    if type (data) ~= "table" then
      return data
    else
      data = raw (data)
      local result = {}
      for k, v in pairs (data) do
        result[k] = v
      end
      return result
    end
  end
end

return shallow_copy
