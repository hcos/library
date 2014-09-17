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

function Data:__tostring ()
  local path = self [PATH]
  local result = "@" .. tostring (path [1]):sub (8)
  for i = 2, #path do
    result = result .. "." .. tostring (path [i])
  end
  return result
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
    data [key] = { [VALUE] = v }
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
  assert (type (x) == "table" and getmetatable (x) == Data)
  local parents = {
    self
  }
  if getmetatable (x) == Data then
    parents [#parents + 1] = x
  elseif getmetatable (x) == Expression then
    for _, v in ipairs (x [PARENTS]) do
      parents [#parents + 1] = v
    end
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
  assert (type (x) == "table" and getmetatable (x) == Data)
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
  end
  return Expression.new (parents)
end

local function value (x)
  local path = x [PATH]
  local function _value (data, i)
    if not data then
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
        if getmetatable (data) == Data then
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

-- Test
-- ----

do
  local cosy = Data.new {}
  cosy.f1 = {
    t = {
      x = {
        c = 3,
      },
    },
  }
  cosy.f2 = {
    t = {
      x = {
        a = 1,
      },
      y = {
        z = true,
      },
      z = cosy.f1.t,
    },
  }
  cosy.m = (cosy.f1.t + cosy.f2.t) {
    x = {
      b = 2,
    },
    y = {
      [VALUE] = 5,
    },
  }
  print (tostring (cosy.m.x.a) .. " = " .. tostring (value (cosy.m.x.a)))
  print (tostring (cosy.m.x.b) .. " = " .. tostring (value (cosy.m.x.b)))
  print (tostring (cosy.m.x.c) .. " = " .. tostring (value (cosy.m.x.c)))
  print (tostring (cosy.m.x  ) .. " = " .. tostring (value (cosy.m.x  )))
  print (tostring (cosy.m.y  ) .. " = " .. tostring (value (cosy.m.y  )))
  print (tostring (cosy.m.z  ) .. " = " .. tostring (value (cosy.m.z  )))
end

