local tags = require "cosy.util.tags"

local IS_TAG = tags.IS_TAG

local function is_tag (x)
  return type (x) == "table" and x [IS_TAG]
end

return is_tag
