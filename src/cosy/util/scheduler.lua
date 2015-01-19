local coroutine = coroutine
local socket    = require "socket"

coroutine.make  = require "coroutine.make"

local Socket = {}

Socket.__index = Socket

function Socket:connect (host, port)
  local coroutine = self.coroutine
  local socket    = self.socket
  socket:settimeout (0)
  repeat
    local ret, err = socket:connect (host, port)
    if not ret then
      if err == "timeout" then
        coroutine.yield ()
      else
        return ret, err
      end
    else
      socket:settimeout (0)
      return ret
    end
  until false
end

function Socket:close (...)
  local socket = self.socket
--  socket:shutdown ()
  socket:close (...)
end

function Socket:receive (pattern)
  local coroutine = self.coroutine
  local socket    = self.socket
  socket:settimeout (0)
  pattern = pattern or "*l"
  repeat
    local s, err = socket:receive (pattern)
    if not s and err == "timeout" then
      coroutine.yield ()
    elseif not s then
      error (err)
    else
      return s
    end
  until false
end

function Socket:send (data, from, to)
  local coroutine = self.coroutine
  local socket    = self.socket
  socket:settimeout (0)
  from = from or 1
  local s, err
  local last = from - 1
  repeat
    s, err, last = socket:send (data, last + 1, to)
    if not s and err == "timeout" then
      coroutine.yield ()
    elseif not s then
      error (err)
    else
      return s
    end
  until false
end

function Socket.flush ()
end

function Socket:setoption (...)
  local socket = self.socket
  socket:setoption (...)
end

function Socket:settimeout (...)
  local socket = self.socket
  socket:settimeout (...)
end

function Socket:getfd (...)
  local socket = self.socket
  return socket:getfd (...)
end

function Socket:setfd (...)
  local socket = self.socket
  return socket:setfd (...)
end

local Scheduler = {}

Scheduler.__index = Scheduler

function Scheduler.create ()
  return setmetatable ({
    threads   = {},
    _last     = 0,
    coroutine = coroutine.make (),
  }, Scheduler)
end

function Scheduler.addthread (scheduler, f, ...)
  local threads   = scheduler.threads
  local coroutine = scheduler.coroutine
  local i         = #threads + 1
  local args      = { ... }
  threads [i]     = coroutine.create (function () f (table.unpack (args)) end)
  scheduler._last = math.max (i, scheduler._last)
end

function Scheduler.addserver (scheduler, socket, handler)
  local coroutine = scheduler.coroutine
  scheduler:addthread (function ()
    while not scheduler.stopping do
      socket:settimeout (0)
      local client, err = socket:accept ()
      if not client and err == "timeout" then
        coroutine.yield ()
      elseif not client then
        error (err)
      else
        scheduler:addthread (function ()
          local status, err = pcall (handler, scheduler:wrap (client))
          if not status then
            scheduler.logger:warn (err)
          end
          client:close ()
        end)
      end
    end
  end)
end

function Scheduler.pass (scheduler)
  local coroutine = scheduler.coroutine
  coroutine.yield ()
end

function Scheduler.stop (scheduler, brutal)
  scheduler.stopping  = true
  scheduler.addthread = function ()
    error "Method addthread is disabled."
  end
  scheduler.addserver = function ()
    error "Method addserver is disabled."
  end
  if brutal then
    local threads = scheduler.threads
    for i in pairs (threads) do
      threads [i] = nil
    end
    scheduler._last = 0
  end
end

function Scheduler.loop (scheduler)
  local threads   = scheduler.threads
  local coroutine = scheduler.coroutine
  local i         = 1
  local last_time = 0
  while scheduler._last ~= 0 do
    local current = threads [i]
    if current ~= nil then
      local status, err = coroutine.resume (current)
      if not status then
        scheduler.logger:warn (err)
      end
      if coroutine.status (current) == "dead" then
        threads [i] = nil
      end
    end
    if not threads [i] then
      for j = scheduler._last, 0, -1 do
        if threads [j] then
          break
        else
          scheduler._last = j-1
        end
      end
    end
    i = i >= scheduler._last and 1 or i + 1
    if i == 1 then
      local current_time = socket.gettime ()
      if current_time - last_time < 0.001 then
        socket.sleep (50)
      end
      last_time = current_time
    end
  end
end

function Scheduler.wrap (scheduler, socket)
  return setmetatable ({
    coroutine = scheduler.coroutine,
    socket    = socket,
  }, Socket)
end

return Scheduler
