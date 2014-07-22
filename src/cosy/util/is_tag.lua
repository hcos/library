local tags = require "cosy.util.tags"
local raw  = require "cosy.util.raw"

local IS_TAG = tags.IS_TAG

local function is_tag (x)
  local r = raw (x)
  return r and type (r) == "table" and r [IS_TAG]
end

return is_tag
