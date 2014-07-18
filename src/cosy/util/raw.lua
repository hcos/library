-- Access to raw data
-- ==================
--
-- The `raw` function returns the raw data behind any data (already a raw
-- one or a proxy).
--
-- ### Usage
--
--       local r = raw (x)
--
-- This function is usable on all Lua values, even strings or numbers.
-- When its parameter is a proxy, the raw data behind is returned.
-- Otherwise, the parameter is returned unchanged.
--
-- ### Implementation
--
-- Implementation is trivial: we use iteratively the `DATA` field until
-- it does not exist anymore. The raw data is then reached.

local is_proxy = require "cosy.util.is_proxy"
local tags     = require "cosy.util.tags"

local DATA = tags.DATA

local function raw (x)
  local result = x
  while is_proxy (result) do
    result = rawget (result, DATA)
  end
  return result
end

return raw
