local tags    = require "cosy.util.tags"
local is_data = require "cosy.util.is_data"

local PATH    = tags.PATH
local PARENTS = tags.PARENTS
local VALUE   = tags.VALUE

local function value (x)
  local path = x [PATH]
  local function _value (data, i)
    if data == nil then
      return nil
    end
    local key = path [i]
    if key then
      assert (type (data) == "table")
      local subdata = data [key]
      local result  = _value (subdata, i + 1)
      if result then
        return result
      end
    else
      if type (data) == "table" then
        if is_data (data) then
          return data
        else
          return data [VALUE]
        end
      end
      return data
    end
    for _, subpath in ipairs (data [PARENTS] or {}) do
      for j = i, #path do
        subpath = subpath [path [j]]
      end
      local result = value (subpath)
      if result then
        return result
      end
    end
    return nil
  end
  return _value (path [1], 2)
end

return value
