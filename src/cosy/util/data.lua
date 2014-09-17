local tags  = require "cosy.util.tags"

local PATH    = tags.PATH
local PARENTS = tags.PARENTS
local VALUE   = tags.VALUE

local Data = {}
Data.on_write = {}

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

local function clear (x)
  local path = x [PATH]
  local data = path [1]
  for i = 2, #path-1 do
    data = data [path [i]]
    if type (data) ~= "table" then
      return
    end
  end
  data [path [#path]] = nil
end

function Data:__newindex (key, value)
  local target = self [key]
  local path   = self [PATH]
  local data   = path [1]
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
  local reverse
  if type (value) ~= "table" and type (v) ~= "table" then
    reverse = function () self [key] = v end
    data [key] = value
  elseif type (value) ~= "table" and type (v) == "table" then
    local old_value = v [VALUE]
    reverse = function () self [key] = old_value end
    v [VALUE] = value
  elseif type (value) == "table" and type (v) ~= "table" then
    reverse = function () clear (target); self [key] = v end
    if not value [VALUE] then
      value [VALUE] = v
    end
    data [key] = value
  elseif type (value) == "table" and type (v) == "table" then
    reverse = function () clear (target); self [key] = v end
    if not value [VALUE] then
      value [VALUE] = v [VALUE]
    end
    data [key] = value
  end
  for _, f in pairs (Data.on_write) do
    if type (f) == "function" then
      f (target, value, reverse)
    end
  end
  -- Clean:
  local path = self [key] [PATH]
  local data = path [1]
  local traversed = {data}
  for i = 2, #path do
    data = data [path [i]]
    if type (data) ~= "table" then
      break
    end
    traversed [#traversed + 1] = data
  end
  for i = #traversed, 2, -1 do
    local d = traversed [i]
    if pairs (d) (d) == nil then
      traversed [i-1] [path [i]] = nil
    else
      break
    end
  end
end

function Data:__len ()
  local i = 1
  while true do
    if not Data.exists (self [i]) then
      break
    end
    i = i + 1
  end
  return i - 1
end

function Data:__ipairs ()
  return coroutine.wrap (
    function ()
      local i = 1
      while true do
        local r = self [i]
        if not Data.exists (r) then
          break
        end
        coroutine.yield (i, r)
        i = i +1
      end
    end
  )
end

function Data:__pairs ()
  local path = self [PATH]
  local function compute (data, i)
    local seen = {}
    if not data then
      return
    end
    local key = path [i]
    if key then
      assert (type (data) == "table")
      local subdata = data [key]
      for k, v in coroutine.wrap (function () compute (subdata, i+1) end) do
        if not seen [k] then
          coroutine.yield (k, v)
          seen [k] = true
        end
      end
    else
      if type (data) == "table" then
        for k, v in pairs (data) do
          if k ~= PARENTS then
            coroutine.yield (k, v)
          end
        end
      end
    end
    for _, subpath in ipairs (data [PARENTS] or {}) do
      for j = i, #path do
        subpath = subpath [path [j]]
      end
      for k, v in pairs (subpath) do
        if not seen [k] then
          coroutine.yield (k, v)
          seen [k] = true
        end
      end
    end
  end
  return coroutine.wrap (
    function ()
      compute (path [1], 2)
    end
  )
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

function Data.is (x)
  return type (x) == "table"
     and getmetatable (x) == Data
end

function Data.exists (x)
  if type (x) ~= "table" or getmetatable (x) ~= Data then
    return false
  end
  local path = x [PATH]
  assert (#path < 8)
  local function _exists (data, i)
    if data == nil then
      return false
    end
    local key = path [i]
    if key then
      assert (type (data) == "table")
      local subdata = data [key]
      if _exists (subdata, i + 1) then
        return true
      end
    else
      return true
    end
    for _, subpath in ipairs (data [PARENTS] or {}) do
      for j = i, #path do
        subpath = subpath [path [j]]
      end
      if Data.exists (subpath) then
        return true
      end
    end
    return false
  end
  return _exists (path [1], 2)
end

function Data.value (x)
  if type (x) ~= "table" or getmetatable (x) ~= Data then
    return nil
  end
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
        if Data.is (data) then
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
      local result = Data.value (subpath)
      if result then
        return result
      end
    end
    return nil
  end
  return _value (path [1], 2)
end

return Data
