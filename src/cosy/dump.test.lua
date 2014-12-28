local assert   = require "luassert"
local dump     = require "cosy.dump"
local Data     = require "cosy.data"

do
  local NAME = Data.tags.NAME
  local root = Data.new {
    [NAME] = "root"
  }
  assert.are.equal (dump (root), "root")
end
