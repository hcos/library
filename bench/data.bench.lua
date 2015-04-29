local profiler   = false
local quantity   = 1000000
local assert     = require "luassert"
local Repository = require "cosy.resource"
local Platform   = require "cosy.platform"

local function test_write ()
  local repository = Data.new {}
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

local function test_read ()
  for _, width in ipairs {
    1, 2, 5, 10, 20,
  } do
    for _, depth in ipairs {
      1, 2, 5, 10, 20,
    } do
      local repository = Data.new {}
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
--[[
      local memory = math.ceil (collectgarbage ("count")/1024)
      print ("Memory         : " .. tostring (memory) .. " Mbytes.")
      local duration = finish - start
      local average_time = math.floor (quantity / duration)
      print ("Average time   : " .. tostring (average_time) .. " operations / second.")
      local average_memory = math.floor (memory*1024*1024 / quantity)
      print ("Average memory : " .. tostring (average_memory) .. " bytes / object.")
--]]
    end
  end
end

for _, f in ipairs {
  test_write,
  test_read,
} do
  if profiler then
    profiler = require "profiler"
    profiler:start "data.out"
  end
  f ()
  if profiler then
    profiler:stop()
  end
end

