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
-- type as parameter..

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
local pairs = pairs
local type  = type

-- The `type` replacement is a table acting also as a function. The latter
-- requires a metatable with the `__call` function.
local itype_mt = {}

-- The function uses the standard Lua `type` function internally, and
-- overrides its result in the case of tables. In this case, it iterates
-- over the mapping to find the first matching detector. It then returns the
-- corresponding type name.
function itype_mt:__call (x)
  local luatype = type (x)
  local result = {
    [luatype] = true
  }
  if luatype == "table" then
    for k, f in pairs (self) do
      if f (x) then
        result [k] = true
      end
    end
  end
  return result
end

-- The module only exports the replacement for `type`.
return setmetatable ({}, itype_mt)
