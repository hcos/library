-- Tags
-- ====

-- Internal mechanisms require to store some information in the data. In
-- order to avoid name conflicts with user defined keys, we use tables as
-- keys for internal information. Such keys are called  __tags__.
--
-- ### Usage
--
--       local tags = require "cosy.util" . tags
--       local TAG = tags.TAG -- Uppercase by convention for tags

-- ### Implementation
--
-- The implementation relies on overriding the `__index` behavior. Whenever
-- a non existing tag is accessed, it is created on the fly.

local mt = {}

-- __Trick:__ the newly created tag is added as early as possible to the
-- `tags`. This is required to avoid infinite loops when defining the three
-- tags used within tags.
function mt:__index (key)
  local result = {}
  self [key] = result
  result [self.NAME  ] = key
  result [self.IS_TAG] = true
  return result
end

local tags = setmetatable ({}, mt)

return tags
