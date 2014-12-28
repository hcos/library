require "cosy.util.string"

local PREVIOUS_DATA = {}
local PREVIOUS_KEY  = {}
local ROOT          = {}
local DEPTH         = {}

local PARENT  = "cosy:parent"
local PARENTS = "cosy:parents"
local VALUE   = "cosy:value"
local NAME    = "cosy:name"

local Data = {
  tags = {
    PARENT  = PARENT,
    PARENTS = PARENTS,
    VALUE   = VALUE,
    NAME    = NAME,
  },
}

Data.on_write = {}

local Expression = {}

function Data.new (x)
  return setmetatable ({
    [ROOT         ] = x,
    [PREVIOUS_DATA] = false,
    [PREVIOUS_KEY ] = false,
    [DEPTH        ] = 1,
  }, Data)
end

local function data_path (x)
  local r = {}
  while not x [ROOT] do
    r [#r + 1] = x [PREVIOUS_KEY]
    x = x [PREVIOUS_DATA]
  end
  r [#r + 1] = x [ROOT]
  local result = {}
  for i = #r, 1, -1 do
    result [#result + 1] = r [i]
  end
  return result
end

function Data.path (x)
  assert (type (x) == "table" and getmetatable (x) == Data)
  return data_path (x)
end

function Data.root (x)
  assert (type (x) == "table" and getmetatable (x) == Data)
  return x [ROOT]
end

function Data.key (x)
  assert (type (x) == "table" and getmetatable (x) == Data)
  return x [PREVIOUS_KEY]
end

function Data:__index (key)
  return setmetatable ({
    [PREVIOUS_DATA] = self,
    [PREVIOUS_KEY ] = key,
    [ROOT         ] = false,
    [DEPTH        ] = self [DEPTH] + 1
  }, Data)
end

function Data.clear (x)
  local parent = x [PREVIOUS_DATA]
  local key    = x [PREVIOUS_KEY ]
  parent [key] = nil
  parent [key] = {}
end

function Data:__newindex (key, value)
  local target = self [key]
  local path   = data_path (self)
  local data   = path [1]
  local traversed = { data }
  for i = 2, #path do
    local k = path [i]
    local v = data [k]
    if type (v) ~= "table" then
      data [k] = { [VALUE] = v }
    end
    data = data [k]
    traversed [#traversed + 1] = data
  end
  local v = data [key]
  local reverse
  local new_is_value = type (value) ~= "table" or getmetatable (value) ~= nil
  local old_is_value = type (v    ) ~= "table" or getmetatable (v    ) ~= nil
  if new_is_value and old_is_value then
    reverse = function () self [key] = v end
    data [key] = value
  elseif new_is_value and not old_is_value then
    local old_value = v [VALUE]
    reverse = function () self [key] = old_value end
    v [VALUE] = value
  elseif not new_is_value and old_is_value then
    reverse = function () Data.clear (target); self [key] = v end
    if value [VALUE] == nil then
      value [VALUE] = v
    end
    data [key] = value
  elseif not new_is_value and not old_is_value then
    reverse = function () Data.clear (target); self [key] = v end
    if value [VALUE] == nil then
      value [VALUE] = v [VALUE]
    end
    data [key] = value
  end
  traversed [#traversed + 1] = data [key]
  path      [#path      + 1] = key
  -- Clean:
  for i = #traversed, 2, -1 do
    local d = traversed [i]
    if  type (d) == "table"
    and not getmetatable (d)
    and pairs (d) (d) == nil then
      traversed [i-1] [path [i]] = nil
    else
      break
    end
  end
  --
  for _, f in pairs (Data.on_write) do
    assert (type (f) == "function")
    f (target, value, reverse)
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
  local path = data_path (self)
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
        for k, _ in pairs (data) do
          if k ~= PARENT and k ~= PARENTS then
            coroutine.yield (k, self [k])
          end
        end
      end
    end
    for _, subpath in ipairs (data [PARENTS] or { data [PARENT] }) do
      for j = i, #path do
        subpath = subpath [path [j]]
      end
      for k, _ in pairs (subpath) do
        if not seen [k] then
          coroutine.yield (k, self [k])
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
  local current = self
  local result  = {}
  while not current [ROOT] do
    local key = current [PREVIOUS_KEY]
    if type (key) == "string" then
      if key:is_identifier () then
        result [#result + 1] = "." .. key
      else
        result [#result + 1] = "[ " .. key:quote () .. " ]"
      end
    else
      result [#result + 1] = "[" .. tostring (key) .. "]"
    end
    current = current [PREVIOUS_DATA]
  end
  local root = current [ROOT]
  result [#result + 1] = (root [NAME] or "@" .. tostring (root):sub (8))
  local size = #result
  for i = 1, size / 2 do
    result [i], result [size+1-i] = result [size+1-i], result [i]
  end
  return table.concat (result)
end

function Data:__eq (x)
  local lhs = data_path (self)
  local rhs = data_path (x)
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

-- `x / n` restricts `x` to the `n` first (or last) parts of its path.
function Data:__div (x)
  assert (type (x) == "number" and x % 1 == 0 and x ~= 0)
  local depth  = self [DEPTH]
  local steps
  if x > 0 then
    if x >= depth then
      return self
    end
    steps = depth - x
  elseif x < 0 then
    if -x >= depth then
      return nil
    end
    steps = x
  end
  local result = self
  for _ = 1, steps do
    result = result [PREVIOUS_DATA]
  end
  return result
end

function Data:__unm ()
  return Data.dereference (self)
end

function Data:__call (...)
  return Data.value (self)
end

function Data:__mul (x)
  assert (type (x) == "table")
  x [PARENT] = self
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

function Data.is (x)
  return type (x) == "table"
     and getmetatable (x) == Data
end

function Data.exists (x)
  if type (x) ~= "table" or getmetatable (x) ~= Data then
    return false
  end
  local path    = data_path (x)
  local data    = path [1]
  local visited = { data }
  for i = 2, #path do
    data = data [path [i]]
    if data == nil then
      break
    end
    visited [#visited + 1] = data
  end
  if data ~= nil then
    return true
  end
  for i = #visited, 1, -1 do
    data = visited [i]
    for _, subpath in ipairs (data [PARENTS] or { data [PARENT] }) do
      for j = i+1, #path do
        subpath = subpath [path [j]]
      end
      if Data.exists (subpath) then
        return true
      end
    end
  end
  return false
end

function Data.dereference (x)
  if type (x) ~= "table" or getmetatable (x) ~= Data then
    return nil
  end
  local path    = data_path (x)
  local data    = path [1]
  local visited = { data }
  for i = 2, #path do
    data = data [path [i]]
    if type (data) ~= "table" then
      break
    end
    visited [i] = data
  end
  local result
  if type (data) == "table" then
    local mt = getmetatable (data)
    if mt == Data then
      result = data
    elseif mt ~= nil then
      result = data
    else
      result = data [VALUE]
    end
  else
    result = data
  end
  if result  ~= nil then
    return result
  end
  for i = #visited, 1, -1 do
    data = visited [i]
    for _, subpath in ipairs (data [PARENTS] or { data [PARENT] }) do
      for j = i+1, #path do
        subpath = subpath [path [j]]
      end
      result = Data.dereference (subpath)
      if result then
        return result
      end
    end
  end
  return nil
end

function Data:__le (x)
  if type (self) ~= "table" or getmetatable (self) ~= Data
  or type (x   ) ~= "table" or getmetatable (x   ) ~= Data then
    return nil
  end
  return self == x or self < x
end

function Data:__lt (x)
  if type (self) ~= "table" or getmetatable (self) ~= Data
  or type (x   ) ~= "table" or getmetatable (x   ) ~= Data then
    return nil
  end
  local path    = data_path (x)
  local data    = path [1]
  local visited = { data }
  for i = 2, #path do
    data = data [path [i]]
    if type (data) ~= "table" then
      break
    end
    visited [i] = data
  end
  for i = #visited, 1, -1 do
    data = visited [i]
    for _, subpath in ipairs (data [PARENTS] or { data [PARENT] }) do
      for j = i+1, #path do
        subpath = subpath [path [j]]
      end
      local result = subpath == self or self < subpath
      if result then
        return result
      end
    end
  end
  return false
end

function Data.value (x)
  repeat
    x = Data.dereference (x)
  until type (x) ~= "table" or getmetatable (x) ~= Data
  return x
end

return Data