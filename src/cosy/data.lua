            require "cosy.util.string"
local Tag = require "cosy.tag"

local PATH    = Tag.new "PATH"
local PARENT  = Tag.new "PARENT"
local PARENTS = Tag.new "PARENTS"
local VALUE   = Tag.new "VALUE"

local NAME    = Tag.NAME
local ID      = Tag.new "ID"

local Data = {}
Data.on_write = {}

local Expression = {}

local cache = setmetatable ({}, {
  __mode = "v" -- maps strings to objects, delete entry when object disappears
})

function Data.new (x)
  local id     = tostring (x)
  local result = cache [id]
  if not result then
    result = setmetatable ({
      [PATH] = { x },
      [ID  ] = id,
    }, Data)
    cache [id] = result
  end
  return result
end

function Data.id (x)
  assert (type (x) == "table" and getmetatable (x) == Data)
  return rawget (x, ID)
end

function Data:__index (key)
  local id     = self [ID] .. ">" .. type (key) .. ":" .. tostring (key)
  local result = cache [id]
  if not result then
    local path = {}
    for _, x in ipairs (self [PATH]) do
      path [#path + 1] = x
    end
    path [#path + 1] = key
    result = setmetatable ({
      [PATH] = path,
      [ID  ] = id,
    }, Data)
    cache [id] = result
  end
  return result
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
    if type (v) ~= "table" then
      data [k] = { [VALUE] = v }
    end
    data = data [k]
  end
  local v = data [key]
  local reverse
  local is_value = type (value) ~= "table" or getmetatable (value) ~= nil
  if is_value and type (v) ~= "table" then
    reverse = function () self [key] = v end
    data [key] = value
  elseif is_value and type (v) == "table" then
    local old_value = v [VALUE]
    reverse = function () self [key] = old_value end
    v [VALUE] = value
  elseif not is_value and type (v) ~= "table" then
    reverse = function () clear (target); self [key] = v end
    if value [VALUE] == nil then
      value [VALUE] = v
    end
    data [key] = value
  elseif not is_value and type (v) == "table" then
    reverse = function () clear (target); self [key] = v end
    if value [VALUE] == nil then
      value [VALUE] = v [VALUE]
    end
    data [key] = value
  end
  --
  for _, f in pairs (Data.on_write) do
    assert (type (f) == "function")
    f (target, value, reverse)
  end
  -- Clean:
  path = target [PATH]
  data = path [1]
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
    if not getmetatable (d) and pairs (d) (d) == nil then
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
          if k ~= PARENT and k ~= PARENTS then
            coroutine.yield (k, v)
          end
        end
      end
    end
    for _, subpath in ipairs (data [PARENTS] or { data [PARENT] }) do
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
  local path   = self [PATH]
  local result = path [1] [NAME] or "@" .. tostring (path [1]):sub (8)
  for i = 2, #path do
    local key = path [i]
    if type (key) == "string" then
      if key:is_identifier () then
        result = result .. "." .. key
      else
        result = result .. " [ " .. key:quote () .. " ]"
      end
    else
      result = result .. " [" .. tostring (key) .. "]"
    end
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

function Data:__le (x)
  local lhs = self [PATH]
  local rhs = x    [PATH]
  if #lhs > #rhs then
    return false
  end
  for i, l in ipairs (lhs) do
    if l ~= rhs [i] then
      return false
    end
  end
  return true
end

function Data:__lt (x)
  local lhs = self [PATH]
  local rhs = x    [PATH]
  if #lhs >= #rhs then
    return false
  end
  for i, l in ipairs (lhs) do
    if l ~= rhs [i] then
      return false
    end
  end
  return true
end

function Data:__mod (x)
  assert (type (x) == "table" and getmetatable (x) == Data)
  if x < self then
    local lhs  = self [PATH]
    local rhs  = x    [PATH]
    local root = rhs [1]
    for i = 2, #rhs do
      root = root [rhs [i]]
    end
    local result = Data.new (root)
    for i = #rhs+1, #lhs do
      result = result [lhs [i]]
    end
    return result
  else
    return self
  end
end

function Data:__div (x)
  assert (type (x) == "number" and x % 1 == 0 and x ~= 0)
  local path   = self [PATH]
  local root   = path [1]
  local result = Data.new (root)
  if x > 0 then
    for i = 2, math.min (#path, x) do
      result = result [path [i]]
    end
  elseif x < 0 then
    for i = 2, math.max (1, #path + x) do
      result = result [path [i]]
    end
  end
  return result
end

function Data:__mul (x)
  assert (type (x) == "table")
  x [PARENT] = self
  return x
end

function Data:__call (...)
  local f = Data.value (self)
  if type (f) == "function" or type (f) == "thread" then
    return f (...)
  else
    local args = table.pack (...)
    assert (#args == 0)
    return f
  end
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

function Data:__unm ()
  return Data.dereference (self)
end

function Expression.new (...)
  local parents = {}
  for _, p in ipairs (...) do
    parents [#parents + 1] = p
  end
  return setmetatable ({
    [PARENTS] = parents
  }, Expression)
end

function Expression:__mul (x)
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

function Data.path (x)
  if type (x) ~= "table" or getmetatable (x) ~= Data then
    return nil
  end
  return x [PATH]
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
    for _, subpath in ipairs (data [PARENTS] or { data [PARENT] }) do
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

function Data.dereference (x)
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
        elseif getmetatable (data) then
          return data
        else
          return data [VALUE]
        end
      end
      return data
    end
    for _, subpath in ipairs (data [PARENTS] or { data [PARENT] }) do
      for j = i, #path do
        subpath = subpath [path [j]]
      end
      local result = Data.dereference (subpath)
      if result then
        return result
      end
    end
    return nil
  end
  return _value (path [1], 2)
end

function Data.value (x)
  repeat
    x = Data.dereference (x)
  until not Data.is (x)
  return x
end

function Data.parents (x, result)
  if type (x) ~= "table" or getmetatable (x) ~= Data then
    return { [x] = true }
  end
  result     = result or { }
  local path = x [PATH]
  local function _parents (data, current, i)
    if data == nil then
      return
    end
    local key = path [i]
    if key then
      assert (type (data) == "table")
      local subdata = data [key]
      _parents (data [key], current [key], i + 1)
    else
      print "here"
      if type (data) == "table" then
        if Data.is (data) then
          result [data] = true
        elseif getmetatable (data) then
          result [data] = true
        elseif data [VALUE] ~= nil then
          result [data [VALUE]] = true
        end
      else
        result [data] = true
      end
    end
    for _, subpath in ipairs (data [PARENTS] or { data [PARENT] }) do
      for j = i, #path do
        subpath = subpath [path [j]]
      end
      Data.parents (subpath, result)
    end
  end
  _parents (path [1], x / 1, 2)
  return result
end

return Data
