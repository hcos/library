local assert  = require "luassert"
local is_data = require "cosy.util.is_data"
local data    = require "cosy.util.data"

do
  assert.is_false (is_data (1))
  assert.is_false (is_data {} )
end

do
  local d = data {}
  assert.is_true (is_data (d))
  assert.is_true (is_data (d.x))
end
