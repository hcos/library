-- Proxies
-- =======
--
-- TODO: explain more on data
--
-- Data is represented as raw tables, and operations are implemented either
-- as functions, or as proxies over raw data.
-- The goal of this design decision is to allow easy exchange of data over
-- the network, and to select the behaviors depending on the context.
--
-- Proxy specific tags
-- -------------------
local tags = require "cosy.util.tags"
--
-- The `DATA` tag is meant to be used only in proxies, to identify the data
-- behind the proxy.
--
local DATA = tags.DATA

-- The `IS_PROXY` tag is also meant to be used only as `x [IS_PROXY] =
-- true` to identify proxies. The `DATA` tag alone is not sufficient, as
-- proxies over the `nil` value do not define the `DATA` tag.
--
local IS_PROXY = tags.IS_PROXY

-- ### Warning
--
-- Proxies can be stacked. Thus, a `DATA` field can be assigned to another
-- proxy.

-- Proxy type
-- ----------
local raw      = require "cosy.util.raw"
local is_proxy = require "cosy.util.is_proxy"
local copy     = require "cosy.util.shallow_copy"

local metatable = {}

local EQ = {}
local LT = {}
local LE = {}

function metatable:__tostring ()
  return tostring (rawget (self, DATA))
end

function metatable:__len ()
  return # rawget (self, DATA)
end

function metatable:__index (key)
  local below = rawget (self, DATA)
  local mt    = getmetatable (self)
  return mt (below [key])
end

function metatable:__newindex (key, value)
  rawget (self, DATA) [key] = value
end

function metatable.__eq (lhs, rhs)
  lhs = raw (lhs)
  rhs = raw (rhs)
  local lhs_mt = getmetatable (lhs)
  local rhs_mt = getmetatable (rhs)
  local lhs_back = lhs_mt.__eq
  local rhs_back = rhs_mt.__eq
  lhs_mt.__eq = lhs_mt [EQ]
  rhs_mt.__eq = rhs_mt [EQ]
  local result = lhs == rhs
  lhs_mt.__eq = lhs_back
  rhs_mt.__eq = rhs_back
  return result
end

function metatable.__lt (lhs, rhs)
  lhs = raw (lhs)
  rhs = raw (rhs)
  local lhs_mt = getmetatable (lhs)
  local rhs_mt = getmetatable (rhs)
  local lhs_back = lhs_mt.__lt
  local rhs_back = rhs_mt.__lt
  lhs_mt.__lt = lhs_mt [LT]
  rhs_mt.__lt = rhs_mt [LT]
  local result = lhs < rhs
  lhs_mt.__lt = lhs_back
  rhs_mt.__lt = rhs_back
  return result
end

function metatable.__le (lhs, rhs)
  lhs = raw (lhs)
  rhs = raw (rhs)
  local lhs_mt = getmetatable (lhs)
  local rhs_mt = getmetatable (rhs)
  local lhs_back = lhs_mt.__le
  local rhs_back = rhs_mt.__le
  lhs_mt.__le = lhs_mt [LE]
  rhs_mt.__le = rhs_mt [LE]
  local result = lhs <= rhs
  lhs_mt.__le = lhs_back
  rhs_mt.__le = rhs_back
  return result
end

function metatable:__call (...)
  local below = rawget (self, DATA)
  local mt    = getmetatable (self)
  return mt (below (...))
end

function metatable:__unm ()
  local below = rawget (self, DATA)
  local mt    = getmetatable (self)
  return mt (-below)
end

function metatable.__add (lhs, rhs)
  if is_proxy (lhs) then
    local below = rawget (lhs, DATA)
    local mt    = getmetatable (lhs)
    return mt (below + rhs)
  elseif is_proxy (rhs) then
    local below = rawget (rhs, DATA)
    local mt    = getmetatable (rhs)
    return mt (lhs + below)
  end
end

function metatable.__sub (lhs, rhs)
  if is_proxy (lhs) then
    local below = rawget (lhs, DATA)
    local mt    = getmetatable (lhs)
    return mt (below - rhs)
  elseif is_proxy (rhs) then
    local below = rawget (rhs, DATA)
    local mt    = getmetatable (rhs)
    return mt (lhs - below)
  end
end

function metatable.__mul (lhs, rhs)
  if is_proxy (lhs) then
    local below = rawget (lhs, DATA)
    local mt    = getmetatable (lhs)
    return mt (below * rhs)
  elseif is_proxy (rhs) then
    local below = rawget (rhs, DATA)
    local mt    = getmetatable (rhs)
    return mt (lhs * below)
  end
end

function metatable.__div (lhs, rhs)
  if is_proxy (lhs) then
    local below = rawget (lhs, DATA)
    local mt    = getmetatable (lhs)
    return mt (below / rhs)
  elseif is_proxy (rhs) then
    local below = rawget (rhs, DATA)
    local mt    = getmetatable (rhs)
    return mt (lhs / below)
  end
end

function metatable.__mod (lhs, rhs)
  if is_proxy (lhs) then
    local below = rawget (lhs, DATA)
    local mt    = getmetatable (lhs)
    return mt (below % rhs)
  elseif is_proxy (rhs) then
    local below = rawget (rhs, DATA)
    local mt    = getmetatable (rhs)
    return mt (lhs % below)
  end
end

function metatable.__pow (lhs, rhs)
  if is_proxy (lhs) then
    local below = rawget (lhs, DATA)
    local mt    = getmetatable (lhs)
    return mt (below ^ rhs)
  elseif is_proxy (rhs) then
    local below = rawget (rhs, DATA)
    local mt    = getmetatable (rhs)
    return mt (lhs ^ below)
  end
end

function metatable.__concat (lhs, rhs)
  if is_proxy (lhs) then
    local below = rawget (lhs, DATA)
    local mt    = getmetatable (lhs)
    return mt (below .. rhs)
  elseif is_proxy (rhs) then
    local below = rawget (rhs, DATA)
    local mt    = getmetatable (rhs)
    return mt (lhs .. below)
  end
end

metatable.__mode     = nil
metatable [IS_PROXY] = true

local function mt_call (self, x)
  if is_proxy (x) then
    return setmetatable ({
      [DATA] = x,
    }, self)
  elseif type (x) == "table" then
    local mt = getmetatable (x)
    if not mt then
      setmetatable (x, {
        __eq = metatable.__eq,
        __lt = metatable.__lt,
        __le = metatable.__le,
      })
    else
      if mt.__eq ~= metatable.__eq then
        mt [EQ], mt.__eq = mt.__eq, metatable.__eq
      end
      if mt.__lt ~= metatable.__lt then
        mt [LT], mt.__lt = mt.__lt, metatable.__lt
      end
      if mt.__le ~= metatable.__le then
        mt [LE], mt.__le = mt.__le, metatable.__le
      end
    end
    return setmetatable ({
      [DATA] = x,
    }, self)
  else
    return x
  end
end

local function proxy ()
  local result = copy (metatable)
  return setmetatable (result, {
    __call = mt_call,
  })
end

return proxy
