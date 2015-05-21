#! /usr/bin/env luajit

local Library       = require "cosy.library"
local Value         = require "cosy.value"
local Scheduler     = require "cosy.scheduler"
local Socket        = require "socket"
      Socket.unix   = require "socket.unix"
local Lfs           = require "lfs"
local Mime          = require "mime"

local directory  = os.getenv "HOME" .. "/.cosy"
local socketfile = directory .. "/socket"

if Lfs.attributes (directory, "mode") ~= "directory" then
  os.remove (directory)
  assert (Lfs.mkdir (directory))
end
os.remove (socketfile)

local socket = Socket.unix ()
socket:bind (socketfile)
os.execute ([[ chmod 0700 %{socketfile} ]] % {
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
      connection:send (result)
    end
  end)
  if not ok then
    err = Value.expression (err)
    err = Mime.b64         (err)
    connection:send (err)
  end
end)

Scheduler.loop ()
