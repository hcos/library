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
  os.execute ([[ chmod 0700 %{file} ]] % { file = socketfile })
  local libraries = {}
  Scheduler.addserver (socket, function (connection)
    local ok, err = pcall (function ()
      while true do
        local message = connection:receive "*l"
        if     message == Daemon.Messages.stop then
          Daemon.stop ()
          return
        elseif message == Daemon.Messages.update then
          Daemon.update ()
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
        local result  = library [operation] (parameters, try_only)
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
  os.remove (socketfile)
  os.exit   (0)
end

function Daemon.update ()
end

return Daemon