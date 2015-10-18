require "cosy.loader.server"

local Configuration = require "cosy.configuration"
local File          = require "cosy.file"
local I18n          = require "cosy.i18n"
local Library       = require "cosy.library"
local Arguments     = require "argparse"
local Colors        = require "ansicolors"

Configuration.load {
  "cosy.nginx",
  "cosy.server",
}

local i18n   = I18n.load {
  "cosy.cli",
  "cosy.server",
}
i18n._locale = Configuration.server.locale

local name = os.getenv "COSY_PREFIX" .. "/bin/cosy-server"
name = name:gsub (os.getenv "HOME", "~")
local parser = Arguments () {
  name        = name,
  description = i18n ["command"] % {},
}
local start  = parser:command "start" {
  description = i18n ["command:start"] % {},
}
start:flag "-f" "--force" {
  description = i18n ["flag:force"] % {},
}
start:flag "-c" "--clean" {
  description = i18n ["flag:clean"] % {},
}
local stop   = parser:command "stop" {
  description = i18n ["command:stop"] % {},
}
stop:flag "-f" "--force" {
  description = i18n ["flag:force"] % {},
}
local arguments = parser:parse ()

local data = File.decode (Configuration.server.data)

if arguments.start then
  local url = "http://{{{host}}}:{{{port}}}/" % {
    host = "localhost",
    port = Configuration.http.port,
  }
  local client = Library.connect (url)
  if client then
    if arguments.force and data then
      local result = client.server.stop {
        administration = data.token,
      }
      if not result then
        os.execute ([[ kill -9 {{{pid}}} 2> /dev/null ]] % {
          pid = data.pid,
        })
      end
    else
      print (Colors ("%{black redbg}" .. i18n ["failure"] % {}),
             Colors ("%{red blackbg}" .. i18n ["server:already-running"] % {}))
      os.exit (1)
    end
  end

  if arguments.clean then
    Configuration.load "cosy.redis"
    local Redis     = require "redis"
    local host      = Configuration.redis.interface
    local port      = Configuration.redis.port
    local database  = Configuration.redis.database
    local redis     = Redis.connect (host, port)
    redis:select (database)
    redis:flushdb ()
    package.loaded ["redis"] = nil
  end

  os.execute ([==[
    rm -f {{{log}}} {{{data}}}
    luajit -e '_G.logfile = "{{{log}}}"; require "cosy.server" .start ()' &
  ]==] % {
    log  = Configuration.server.log,
    data = Configuration.server.data,
  })
  local tries = 0
  local serverdata, nginxdata
  repeat
    os.execute ([[sleep {{{time}}}]] % { time = 0.5 })
    serverdata = File.decode (Configuration.server.data)
    nginxdata  = File.decode (Configuration.http  .pid)
    tries      = tries + 1
  until (serverdata and nginxdata) or tries == 5
  if serverdata and nginxdata then
    print (Colors ("%{black greenbg}" .. i18n ["success"] % {}))
    os.exit (0)
  else
    print (Colors ("%{black redbg}" .. i18n ["failure"] % {}),
           Colors ("%{red blackbg}" .. i18n ["server:unreachable"] % {}))
    os.exit (1)
  end

elseif arguments.stop then

  local url = "http://{{{host}}}:{{{port}}}/" % {
    host = "localhost",
    port = Configuration.http.port,
  }
  local client = Library.connect (url)
  if client and data then
    local result = client.server.stop {
      administration = data.token,
    }
    if result  then
      print (Colors ("%{black greenbg}" .. i18n ["success"] % {}))
      os.exit (0)
    end
  end
  if not client then
    if arguments.force and data then
      os.execute ([[ kill -9 {{{pid}}} 2> /dev/null ]] % {
        pid = data.pid,
      })
      print (Colors ("%{black greenbg}" .. i18n ["success"] % {}))
      os.exit (0)
    elseif arguments.force then
      print (Colors ("%{black greenbg}" .. i18n ["success"] % {}))
      os.exit (0)
    else
      print (Colors ("%{black redbg}" .. i18n ["failure"] % {}),
             Colors ("%{red blackbg}" .. i18n ["server:unreachable"] % {}))
      os.exit (1)
    end
  end

end
