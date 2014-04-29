-- Tags repository
-- ===============

-- Data are stored as raw Lua tables. Integer and string keys are reserved
-- to store attributes specified by the users or the tools.
--
-- Internal attributes are identified using special keys, named __tags__.
-- They are obtained using this module.

-- Usage
-- -----
--
--       local tags = require "cosy.lang.tags"
--       local TAG = tags.TAG -- Uppercase by convention for tags
--       print (TAG)          -- Prints "[TAG]"

-- Design
-- ------
--
-- this module returns a single object that acts as a repository for tags. A
-- tag can be created or retrieved in a Lua friendly way.

-- Implementation
-- --------------
--
-- The implementation relies on overriding the `__index` behavior. Whenever
-- a non existing tag is accessed, it is created on the fly.

local tag_mt = {}
local tags_mt = {}
local tags = setmetatable ({}, tags_mt)

-- __Trick:__ the newly created tag is added as early as possible to the
-- `tags`. This is required to avoid infinite loops when defining the three
-- tags used within tags.
function tags_mt:__index (key)
  local result = setmetatable ({}, tag_mt)
  tags [key] = result
  result [tags.RAW  ] = result
  result [tags.NAME ] = key
  result [tags.OWNER] = tags
  return result
end

-- Tags can be output to string easily for debugging.
function tag_mt:__tostring ()
  return "[" .. self [tags.NAME] .. "]"
end

-- Three tags are created by default, as they are used internally to define
-- tags themselves. These definitions are not required, as these three tags
-- will be created when necessary.
local RAW   = tags.RAW
local NAME  = tags.NAME
local OWNER = tags.OWNER

-- The module only exports the `tags` repository.
return tags
