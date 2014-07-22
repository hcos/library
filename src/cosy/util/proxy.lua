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
local ignore   = require "cosy.util.ignore"

local function string (self)
  return tostring (rawget (self, DATA))
end

local function eq (lhs, rhs)
  return raw (lhs) == raw (rhs)
end

local function len (self)
  return # rawget (self, DATA)
end

local function index (self, key)
  local below = rawget (self, DATA)
  local mt    = getmetatable (self)
  if type (below) ~= "table" and type (below) ~= "string" then
    error "attempt to index a non table"
  else
    return mt (below [key])
  end
end

local function newindex_writable (self, key, value)
  rawget (self, DATA) [key] = value
end

local function newindex_readonly (self, key, value)
  ignore (self, key, value)
  error "Attempt to write to a read-only proxy."
end

local eq_mt = {
  __eq = eq,
}

local function call_metatable (self, x)
  if type (x) == "table" then
    local mt = getmetatable (x)
    if not mt then
      setmetatable (x, eq_mt)
    end
  end
  return setmetatable ({
    [DATA] = x,
  }, self)
end

local function proxy (parameters)
  parameters = parameters or {}
  local newindex
  if parameters.read_only then
    newindex = newindex_readonly
  else
    newindex = newindex_writable
  end
  local mt = {
    __call = call_metatable,
  }
  local result = {
    __tostring  = string,
    __eq        = eq,
    __len       = len,
    __index     = index,
    __newindex  = newindex,
    __call      = nil,
    __mode      = nil,
    [IS_PROXY]  = true,
  }
  return setmetatable (result, mt), mt
end

return proxy
