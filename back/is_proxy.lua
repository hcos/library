local tags = require "cosy.util.tags"

local IS_PROXY = tags.IS_PROXY

local function is_proxy (x)
  return type (x) == "table" and
         (getmetatable (x) or {}) [IS_PROXY]
end

return is_proxy
