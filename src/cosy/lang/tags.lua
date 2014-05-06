-- Tags repository
-- ===============

-- Data are stored as raw Lua tables. Integer and string keys are reserved
-- to store attributes specified by the users or the tools.
--
-- Internal attributes are identified using special keys, named __tags__.
-- They are obtained using this module.

-- Design
-- ------
--
-- this module returns a single object that acts as a repository for tags. A
-- tag can be created or retrieved in a Lua friendly way.

-- Usage
-- -----
--
--       local tags = require "cosy.lang.tags"
--       local TAG = tags.TAG -- Uppercase by convention for tags
--       print (TAG)          -- Prints "[TAG]"

-- Implementation
-- --------------
--
-- The implementation relies on overriding the `__index` behavior. Whenever
-- a non existing tag is accessed, it is created on the fly.

local tag_mt  = {}
local tags_mt = {}
local tags    = setmetatable ({}, tags_mt)

-- Two tags are created by default, as they are used internally to define
-- tags themselves:
--
-- * `NAME` that holds the tag name,
-- * `OWNER` that holds tho owner for any data, and thus also for tags.
--
-- Their explicit definitions is not required, as these
-- tags will be created when necessary.
--
-- __Trick:__ the newly created tag is added as early as possible to the
-- `tags`. This is required to avoid infinite loops when defining the three
-- tags used within tags.
function tags_mt:__index (key)
  local result = setmetatable ({}, tag_mt)
  self [key] = result
  result [self.NAME ] = key
  result [self.OWNER] = self
  return result
end

-- Tags can be output to string easily for debugging.
function tag_mt:__tostring ()
  return "[" .. self [tags.NAME] .. "]"
end

-- The module only exports the `tags` repository.
return tags
