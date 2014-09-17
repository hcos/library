local tags  = require "cosy.util.tags"

local PATH    = tags.PATH
local PARENTS = tags.PARENTS
local VALUE   = tags.VALUE

local Data = {}

local Expression = {}

function Data.new (x)
  return setmetatable ({
    [PATH] = { x }
  }, Data)
end

function Data:__index (key)
  local path = {}
  for _, x in ipairs (self [PATH]) do
    path [#path + 1] = x
  end
  path [#path + 1] = key
  return setmetatable ({
    [PATH] = path
  }, Data)
end

function Data:__newindex (key, value)
  local path = self [PATH]
  local data = path [1]
  for i = 2, #path do
    local k = path [i]
    local v = data [k]
    if not v then
      data [k] = {}
    elseif type (v) ~= "table" then
      data [k] = { [VALUE] = v }
    end
    data = data [k]
  end
  local v = data [key]
  if type (value) ~= "table" and type (v) ~= "table" then
    data [key] = value
  elseif type (value) ~= "table" and type (v) == "table" then
    v [VALUE] = value
    data [key] = v
  elseif type (value) == "table" and type (v) ~= "table" then
    if not value [VALUE] then
      value [VALUE] = v
    end
    data [key] = value
  elseif type (value) == "table" and type (v) == "table" then
    if not value [VALUE] then
      value [VALUE] = v [VALUE]
    end
    data [key] = value
  end
end

function Data:__tostring ()
  local path = self [PATH]
  local result = "@" .. tostring (path [1]):sub (8)
  for i = 2, #path do
    result = result .. "." .. tostring (path [i])
  end
  return result
end

function Data:__eq (x)
  local lhs = self [PATH]
  local rhs = x    [PATH]
  if #lhs ~= #rhs then
    return false
  end
  for i, l in ipairs (lhs) do
    if l ~= rhs [i] then
      return false
    end
  end
  return true
end

function Data:__call (x)
  assert (type (x) == "table")
  local parents = x [PARENTS] or {}
  parents [#parents + 1] = self
  x [PARENTS] = parents
  return x
end

function Data:__add (x)
  assert (type (x) == "table")
  local parents = {}
  parents [#parents + 1] = self
  if getmetatable (x) == Data then
    parents [#parents + 1] = x
  elseif getmetatable (x) == Expression then
    for _, v in ipairs (x [PARENTS]) do
      parents [#parents + 1] = v
    end
  else
    assert (false)
  end
  return Expression.new (parents)
end

function Expression.new (x)
  return setmetatable ({
    [PARENTS] = x
  }, Expression)
end

function Expression:__call (x)
  assert (type (x) == "table")
  local parents = x [PARENTS] or {}
  for _, v in ipairs (self [PARENTS]) do
    parents [#parents + 1] = v
  end
  x [PARENTS] = parents
  return x
end

function Expression:__add (x)
  assert (type (x) == "table")
  local parents = {}
  for _, v in ipairs (self [PARENTS]) do
    parents [#parents + 1] = v
  end
  if getmetatable (x) == Data then
    parents [#parents + 1] = x
  elseif getmetatable (x) == Expression then
    for _, v in ipairs (x [PARENTS]) do
      parents [#parents + 1] = v
    end
  else
    assert (false)
  end
  return Expression.new (parents)
end

return Data.new
