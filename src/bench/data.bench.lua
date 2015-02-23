local assert   = require "luassert"
local Data     = require "cosy.data"
local Platform = require "cosy.platform"

do
  local repository = Data.new {}
  local quantity = 100000
  collectgarbage ()
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

do
  local repository = Data.new {}
  local quantity = 100000
  Data.options (repository) .on_write = function () end
  collectgarbage ()
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

for _, width in ipairs {
  1, 2, 5, 10, 20,
} do
  for _, depth in ipairs {
    1, 2, 5, 10, 20,
  } do
    local repository = Data.new {}
    local quantity = 100000
    repository [0] = {}
    for i = 1, width do
      local t = {}
      local current = t
      for j = 1, depth do
        current [j] = {}
        current     = current [j]
      end
      current._ = i % width + 1
      repository [i] = {
        [i] = t,
        [Data.DEPENDS] = { repository [i-1] },
      }
    end
    repository.all = {
      [Data.DEPENDS] = { repository [width] }
    }
    collectgarbage ()
    local start    = Platform.time ()
    for i = 1, quantity do
      local d = repository.all [i % width + 1]
      for j = 1, depth do
        d = d [j]
      end
      local _ = d._
--      assert.are.equal (d._, i % width + 1)
    end
    local finish   = Platform.time ()
    print ("# read / second / depth - width", depth, width, math.floor (quantity / (finish - start)))
  end
end
