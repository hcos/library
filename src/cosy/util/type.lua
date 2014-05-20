-- Extensible `type` function
-- ==========================

-- This module implements an extensible replacement for Lua `type` function.
-- The replacement allows to define new type names and associate them with
-- detection functions. The new type names can only be used for tables.
--
-- The replacement `type` function does not return a string. Instead, it
-- returns a set of types.

-- Design
-- ------
--
-- This module returns a single object, that acts both as a mapping from
-- type names to detector functions, and as a function taking the object to
-- type as parameter.

-- Usage
-- -----
--
--       local itype = require "cosy.util.type"
--       itype.my_type_name = function (x) ... end
--       if itype (a_data).my_type_name then
--         ...
--       end

-- Implementation
-- --------------

-- Used functions are stored in locals.
local type  = type

-- The `type` replacement is a table acting also as a function. The latter
-- requires a metatable with the `__call` function.
local type_mt = {}
local compute_mt = {}

local data = {}
local itype = setmetatable ({}, type_mt)

-- The function uses the standard Lua `type` function internally, and
-- overrides its result in the case of tables. In this case, it returns a
-- table that maps each type name to the result of the corresponding
-- detection function.
--
function type_mt:__call (x)
  local _ = self
  local luatype = type (x)
  return setmetatable ({ [data] = x, [luatype] = true }, compute_mt)
end

-- The mapping from type names to results of detection functions is done on
-- the fly in this `__index`. Results are stored to avoid useless
-- computations.
--
function compute_mt:__index (k)
  local x = rawget (self, data)
  if type (x) == "table" then
    local f = itype [k]
    if f and type (f) == "function" then
      rawset (self, k, f (x))
    end
  end
  return rawget (self, k) or false
end

-- The module only exports the replacement for `type`.
return itype
