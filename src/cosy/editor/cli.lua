local function printerr (...)
  local t = { ... }
  for i = 1, #t do
    t [i] = tostring (t [i])
  end
  io.stderr:write (table.concat (t, "\t") .. "\n")
end

local arguments
do
  local loader        = require "cosy.loader.lua" {
    logto = false,
  }
  local Configuration = loader.load "cosy.configuration"
  local I18n          = loader.load "cosy.i18n"
  local Arguments     = loader.require "argparse"

  Configuration.load {
    "cosy.editor",
    "cosy.server",
  }

  local i18n   = I18n.load {
    "cosy.editor",
  }
  i18n._locale = Configuration.server.locale

  local parser = Arguments () {
    name        = "cosy-editor",
    description = i18n ["editor:command"] % {},
  }
  parser:option "-a" "--alias" {
    description = i18n ["editor:alias"] % {},
    default     = "default",
  }
  parser:option "-p" "--port" {
    description = i18n ["editor:port"] % {},
    default     = tostring (Configuration.editor.port),
    convert     = tonumber,
  }
  parser:argument "resource" {
    description = i18n ["editor:resource"] % {},
    convert     = function (s)
      assert (s:match "^https?://")
      return s
    end,
  }
  arguments = parser:parse ()
end

local Scheduler = require "copas.ev"
local Hotswap   = require "hotswap.ev".new {
  loop = Scheduler._loop,
}
local loader    = require "cosy.loader.lua" {
  alias     = arguments.alias,
  logto     = false,
  hotswap   = Hotswap,
  scheduler = Scheduler,
}
local Configuration = loader.load "cosy.configuration"
local File          = loader.load "cosy.file"
local I18n          = loader.load "cosy.i18n"
local Library       = loader.load "cosy.library"
local Colors        = loader.require "ansicolors"
local Posix         = loader.require "posix"

Configuration.load {
  "cosy.editor",
}

local i18n   = I18n.load {
  "cosy.editor",
}
i18n._locale = Configuration.server.locale

os.remove (Configuration.server.data)
local pid = Posix.fork ()
if pid == 0 then
  local ev = require "ev"
  ev.Loop.default:fork ()
  File.encode (Configuration.server.data, {
    alias     = arguments.alias,
    http_port = arguments.port
             or (data and data.port)
             or Configuration.http.port,
  })
  local Server = loader.load "cosy.server"
  Server.start ()
  os.exit (0)
end
local tries = 0
local serverdata, nginxdata
repeat
  Posix.sleep (1)
  serverdata = File.decode (Configuration.server.data)
  nginxdata  = File.decode (Configuration.http  .pid)
  tries      = tries + 1
until (serverdata and nginxdata) or tries == 5
if serverdata and nginxdata then
  print (Colors ("%{black greenbg}" .. i18n ["success"] % {}))
  if arguments.heroku then
    Posix.wait (pid)
  end
  os.exit (0)
else
  printerr (Colors ("%{black redbg}" .. i18n ["failure"] % {}),
            Colors ("%{red blackbg}" .. i18n ["server:unreachable"] % {}))
  os.exit (1)
end
