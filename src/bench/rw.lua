local profiler = false

if profiler then
  profiler = require "profiler"
  profiler:start()
end

local max_i = 100
local max_j = 100
local max_k = 10
local max_l = 10
local scheme

local function scheme_1 ()
  scheme = "nested writes"
  local cosy = require "cosy" . cosy
  for i = 1, max_i do
    local di = cosy.m [i]
    for j = 1, max_j do
      local dj = di [j]
      for k = 1, max_k do
        local dk = dj [k]
        for l = 1, max_l do
          local dl = dk [l]
          dl.x = i + j + k + l
        end
      end
    end
  end
end

local function scheme_2 ()
  scheme = "flat writes"
  local cosy = require "cosy" . cosy
  for i = 1, max_i * max_j * max_k * max_l do
    cosy.m [i] = i
  end
end

local function scheme_3 ()
  scheme = "flat read / write"
  local cosy = require "cosy" . cosy
  cosy.m [0] = 1
  for i = 1, max_i * max_j * max_k * max_l do
    cosy.m [i] = cosy.m [i-1] ()
  end
end

local start = os.time ()
scheme_3 ()
local finish = os.time ()

if profiler then
  profiler:stop()
  profiler:writeReport("profiler.txt")
end
collectgarbage ()

print ("Scheme         : " .. scheme .. ".")
local duration = finish - start
print ("Time           : " .. tostring (duration) .. " seconds.")
local memory = math.ceil (collectgarbage ("count")/1024)
print ("Memory         : " .. tostring (memory) .. " Mbytes.")
local count  = max_i * max_j * max_k * max_l
print ("Performed      : " .. tostring (count) .. " writes.")
local average_time = math.floor (count / duration)
print ("Average time   : " .. tostring (average_time) .. " writes / second.")
local average_memory = math.floor (memory*1024*1024 / count)
print ("Average memory : " .. tostring (average_memory) .. " bytes / object.")
