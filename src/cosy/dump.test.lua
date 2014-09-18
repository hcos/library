local assert   = require "luassert"
local dump     = require "cosy.dump"
local Data     = require "cosy.data"
local Tag      = require "cosy.tag"

do
  local root = Data.new {
    [Tag.NAME] = "root"
  }
  print (dump (root))
end
