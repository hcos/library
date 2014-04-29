-- Extensible `type` function
-- ==========================

-- This module implements an extensible replacement for Lua `type` function.
-- The replacement allows to define new type names and associate them with
-- detection functions. The new type names can only be used for tables.

-- Usage
-- -----
--
--       local itype = require "cosy.util.type"
--       itype.my_type_name = function (x) ... end
--       local name = itype (a_data)

-- Design
-- ------
--
-- This module returns a single object, that acts both as a mapping from
-- type names to detector functions, and as a function with the same
-- interface as the standard Lua `type` function.

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
  local result = type (x)
  if result == "table" then
    for k, f in pairs (self) do
      if f (x) then
        result = k
        break
      end
    end
  end
  return result
end

-- The module only exports the replacement for `type`.
return setmetatable ({}, itype_mt)
