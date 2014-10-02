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

require "cosy.util.string"

local Tag_mt = {}
local Tag  = setmetatable ({}, Tag_mt)
local tags = {}

local NAME = setmetatable ({}, Tag)
NAME [NAME] = "NAME"
tags ["NAME"] = NAME

function Tag.new (name)
  assert (type (name) == "string")
  if rawget (tags, name) then
    error ("Tag ${name} already exists." % { name = name:quote () })
  end
  local result  = setmetatable ({}, Tag)
  result [NAME] = name
  tags   [name] = result
  return result
end

function Tag_mt:__index (key)
  local result = rawget (tags, key)
  if result then
    return result
  else
    error ("Tag ${key} does not exist." % { key = key:quote () })
  end
end

function Tag:__tostring ()
  local name = self [NAME]
  if name:is_identifier () then
    return "Tag.${name}" % { name = name }
  else
    return "Tag [ ${name} ]" % { name = name:quote () }
  end
end

function Tag.is (tag)
  return type (tag) == "table"
     and getmetatable (tag) == Tag
end

Tag.new "INSTANCE"
Tag.new "POSITION"
Tag.new "SELECTED"
Tag.new "HIGHLIGHTED"

return Tag
