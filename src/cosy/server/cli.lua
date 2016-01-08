local loader        = require "cosy.loader.lua" {
  logto = false,
}
local Configuration = loader.load "cosy.configuration"
local File          = loader.load "cosy.file"
local I18n          = loader.load "cosy.i18n"
local Library       = loader.load "cosy.library"
local Arguments     = loader.require "argparse"
local Colors        = loader.require "ansicolors"
local Lfs           = loader.require "lfs"
local Posix         = loader.require "posix"

Lfs.mkdir (os.getenv "HOME" .. "/.cosy")

Configuration.load {
  "cosy.nginx", -- TODO: check
  "cosy.server",
}

local i18n   = I18n.load {
  "cosy.client",
  "cosy.server",
}
i18n._locale = Configuration.server.locale

local parser = Arguments () {
  name        = "cosy-server",
  description = i18n ["server:command"] % {},
}
local start = parser:command "start" {
  description = i18n ["server:start"] % {},
}
start:flag "-f" "--force" {
  description = i18n ["flag:force"] % {},
}
start:flag "-c" "--clean" {
  description = i18n ["flag:clean"] % {},
}
local stop = parser:command "stop" {
  description = i18n ["server:stop"] % {},
}
stop:flag "-f" "--force" {
  description = i18n ["flag:force"] % {},
}
local _ = parser:command "version" {
  description = i18n ["server:version"] % {},
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
        Posix.kill (data.pid, 9) -- kill
      end
    else
      print (Colors ("%{black redbg}" .. i18n ["failure"] % {}),
             Colors ("%{red blackbg}" .. i18n ["server:already-running"] % {}))
      os.exit (1)
    end
  end

  if arguments.clean then
    Configuration.load "cosy.redis"
    local Redis     = loader.require "redis"
    local host      = Configuration.redis.interface
    local port      = Configuration.redis.port
    local database  = Configuration.redis.database
    local redis     = Redis.connect (host, port)
    redis:select (database)
    redis:flushdb ()
    package.loaded ["redis"] = nil
  end

  os.remove (Configuration.server.log )
  os.remove (Configuration.server.data)

  if Posix.fork () == 0 then
    package.loaded ["copas"     ] = nil
    package.loaded ["copas.ev"  ] = nil
    package.loaded ["ev"        ] = nil
    package.loaded ["hotswap.ev"] = nil
    package.loaded ["hotswap"   ] = nil
    local Server = loader.require "cosy.server"
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
    if result then
      print (Colors ("%{black greenbg}" .. i18n ["success"] % {}))
      os.exit (0)
    end
  end
  if not client then
    if arguments.force and data then
      Posix.kill (data.pid, 9) -- kill
      local nginx_file = io.open (Configuration.http.pid, "r")
      local nginx_pid  = nginx_file:read "*a"
      nginx_file:close ()
      Posix.kill (nginx_pid:match "%S+", 15) -- term
      print (Colors ("%{black greenbg}" .. i18n ["success"] % {}))
      os.exit (0)
    elseif arguments.force then
      print (Colors ("%{black redbg}" .. i18n ["failure"] % {}))
      os.exit (0)
    else
      print (Colors ("%{black redbg}" .. i18n ["failure"] % {}),
             Colors ("%{red blackbg}" .. i18n ["server:unreachable"] % {}))
      os.exit (1)
    end

  end

elseif arguments.version then

  local path  = package.searchpath ("cosy.server.cli", package.path)
  local parts = {}
  for part in path:gmatch "[^/]+" do
    parts [#parts+1] = part
  end
  parts [#parts] = nil
  parts [#parts] = nil
  path = (path:find "^/" and "/" or "") .. table.concat (parts, "/")
  local handler = assert (io.popen ([[
    source "{{{prefix}}}/bin/realpath.sh"
    cd $(realpath "{{{path}}}")
    git describe
  ]] % {
    prefix = loader.prefix,
    path   = path,
  }, "r"))
  local result, err = assert (handler:read "*a")
  handler:close ()
  if result then
    print (result:match "%S+")
    print (Colors ("%{black greenbg}" .. i18n ["success"] % {}))
    os.exit (0)
  else
    print (Colors ("%{black redbg}" .. i18n ["failure"] % {}),
           Colors ("%{red blackbg}" .. err))
    os.exit (1)
  end

else

  assert (false)

end
