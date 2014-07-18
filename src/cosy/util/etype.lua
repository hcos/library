-- Extensible type
-- ===============

-- Usage
-- -----
--
--       etype.my_type_name = function (x) ... end
--       
--       if etype (a_data).my_type_name then
--         ...
--       end

-- Implementation
-- --------------
local proxy  = require "cosy.util.proxy"
local raw    = require "cosy.util.raw"
local ignore = require "cosy.util.ignore"

local compute, _  = proxy { read_only = true  }
local etype, mt   = proxy { read_only = false }

function mt:__call (x)
  ignore (self)
  local result = compute (x)
  for _, t in ipairs {
    "nil",
    "boolean",
    "number",
    "string",
    "function",
    "thread",
    "table",
  } do
    rawset (result, t, false)
  end
  rawset (result, type (x), true)
  return result
end

function mt:__newindex (key, value)
  rawset (self, key, value)
end

function compute:__index (key)
  local x = raw (self)
  local detector = etype [key]
  if detector then
    rawset (self, key, detector (x) or false)
  end
  return rawget (self, key) or false
end

-- The function uses the standard Lua `type` function internally, and
-- overrides its result in the case of tables. In this case, it returns a
-- table that maps each type name to the result of the corresponding
-- detection function.

return etype
