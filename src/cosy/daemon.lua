#! /usr/bin/env luajit

local Configuration = require "cosy.configuration"
local Library       = require "cosy.library"
local Value         = require "cosy.value"
local Scheduler     = require "cosy.scheduler"
local Socket        = require "socket"
      Socket.unix   = require "socket.unix"
local Lfs           = require "lfs"
local Mime          = require "mime"

local socketfile = Configuration.config.daemon.socket_file._
os.remove (socketfile)

local socket = Socket.unix ()
socket:bind (socketfile)
os.execute ([[ chmod 0600 %{socketfile} ]] % {
  socketfile = socketfile,
})

local libraries = {}

Scheduler.addserver (socket, function (skt)
  local connection = skt:accept ()
  local ok, err = pcall (function ()
    while true do
      local message = connection:receive "*l"
      if not message then
        connection:close ()
        return
      end
      message = Mime.unb64   (message)
      message = Value.decode (message)
      if message == "stop" then
        os.remove (socketfile)
        os.exit   (0)
      end
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

pcall (Scheduler.loop)
os.remove (socketfile)
