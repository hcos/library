-- Tests for the extension of `require` to HTTP URLs
-- =================================================

-- These tests depend on `luassert` for assertions.
local assert = require "luassert"

-- Without the extension, a URL cannot be loaded as a Lua module.
assert.has.error (function ()
  require "https://raw.githubusercontent.com/CosyVerif/lang/master/src/cosy/util/http_require_data.lua"
end)

-- With the extension, a URL can be loaded.
assert.has.no.error (function ()
  require "cosy.util.http_require"
  require "https://raw.githubusercontent.com/CosyVerif/lang/master/src/cosy/util/http_require_data.lua"
end)

-- The extended `require` loads effectively the required module.
local remote_module = require "https://raw.githubusercontent.com/CosyVerif/lang/master/src/cosy/util/http_require_data.lua"
local local_module = require "cosy.util.http_require_data"

-- The distant module and its local equivalent are the same:
assert.are.same (local_module, distant_module)
