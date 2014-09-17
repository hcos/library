local data = require "cosy.util.data"

local x  = data {}
local mt = getmetatable (x)

local function is_data (x)
  if type (x) ~= "table" then
    return false
  end
  return getmetatable (x) == mt
end

return is_data
