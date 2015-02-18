local Data     = require "data"
local Platform = require "cosy.platform"

local repository = Data.as_table (Data.new {})

do
  local quantity = 1000000
  local start    = Platform.time ()
  local depends  = {}
  for i = 1, quantity do
    repository [i] = {
      [i] = i,
    }
    depends [#depends+1] = repository [i]
  end
  repository.all = {
    [Data.DEPENDS] = depends
  }
  local finish   = Platform.time ()
  print ("# create / second:", math.floor (quantity / (finish - start)))
end

for _, depth in ipairs {
  1, 2, 5,
  10, 20, 50,
  100, 200, 500,
} do
  local quantity = 1000000
  local depends  = {}
  for i = 1, depth do
    repository [i] = {
      [i] = i,
    }
    depends [#depends+1] = repository [i]
  end
  repository.all = {
    [Data.DEPENDS] = depends
  }
  local start    = Platform.time ()
  for i = 1, quantity do
    local _ = repository.all [i % depth + 1]._
  end
  local finish   = Platform.time ()
  print ("# read / second / depth", depth, math.floor (quantity / (finish - start)))
end