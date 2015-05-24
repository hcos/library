local Configuration = require "cosy.configuration"
local Library       = require "cosy.library"
local Value         = require "cosy.value"
local Scheduler     = require "cosy.scheduler"
local Socket        = require "socket"
      Socket.unix   = require "socket.unix"
local Mime          = require "mime"

local Daemon = {
  Messages = {
    stop   = "Daemon, stop!",
    update = "Daemon, update!",
  },
}

local socketfile = Configuration.config.daemon.socket_file._

function Daemon.start ()
  os.remove (socketfile)
  local socket = Socket.unix ()
  socket:bind   (socketfile)
  socket:listen (32)
  os.execute ([[ chmod 0600 %{file} ]] % { file = socketfile })
  local libraries = {}
  Scheduler.addserver (socket, function (connection)
    local ok, err = pcall (function ()
      while true do
        local message = connection:receive "*l"
        if     message == Daemon.Messages.stop then
          os.remove (socketfile)
          os.exit   (0)
          return
        elseif message == Daemon.Messages.update then
          return
        elseif not message then
          connection:close ()
          return
        end
        message = Mime.unb64   (message)
        message = Value.decode (message)
        local server     = message.server
        local operation  = message.operation
        local parameters = message.parameters
        local try_only   = message.try_only
        if not libraries [server] then
          libraries [server] = Library.connect (server)
        end
        local library = libraries [server]
        local result
        if library and library._status == "opened" then
          result = library [operation] (parameters, try_only)
        end
        result = Value.expression (result)
        result = Mime.b64         (result)
        connection:send (result .. "\n")
      end
    end)
    if not ok then
      err = Value.expression (err)
      err = Mime.b64         (err)
      connection:send (err)
    end
  end)
  Scheduler.loop ()
end

function Daemon.stop ()
  local socket = Socket.unix ()
  socket:connect (Configuration.config.daemon.socket_file._)
  socket:send (Daemon.Messages.stop .. "\n")
  socket:close ()
end

function Daemon.update ()
  local socket = Socket.unix ()
  socket:connect (Configuration.config.daemon.socket_file._)
  socket:send (Daemon.Messages.update .. "\n")
  socket:close ()
end

local Metatable = {}

function Metatable.__call (_, t)
  local socket  = Socket.unix ()
  socket:connect (Configuration.config.daemon.socket_file._)
  local message = Value.expression {
    server      = t.server,
    operation   = t.operation,
    parameters  = t.parameters,
    try_only    = t.try_only,
  }
  message       = Mime.b64 (message)
  socket:send (message .. "\n")
  local answer  = socket:receive "*l"
  if not answer then
    return nil
  end
  answer        = Mime.unb64 (answer)
  answer        = Value.decode (answer)
  socket:close ()
  return answer
end

return setmetatable (Daemon, Metatable)
