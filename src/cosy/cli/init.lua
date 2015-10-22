local loaded_modules = {}
for k in pairs (package.loaded) do
  loaded_modules [k] = true
end

local Loader = require "cosy.loader.cli"


local Configuration
local File
local I18n
local Cliargs
local Colors
local Lfs
local Websocket
local i18n

local function init ()

  Configuration = require "cosy.configuration"
  File          = require "cosy.file"
  I18n          = require "cosy.i18n"
  Cliargs       = require "cliargs"
  Colors        = require "ansicolors"
  Lfs           = require "lfs"
  Websocket     = require "websocket"

  Configuration.load {
    "cosy.cli",
    "cosy.daemon",
  }

  i18n = I18n.load {
    "cosy.cli",
    "cosy.commands",
    "cosy.daemon",
  }
  i18n._locale = Configuration.cli.locale

end

init()


local Cli = {}

Cli.__index = Cli

function Cli.new ()
  return setmetatable ({}, Cli)
end

-----------------------------
--  While not found Cli tries to determine what server it will connect to
--    by scanning in that order :
--  1. --server=xxx   cmd line option
--  2. ~/.cosy/cli.data config file (ie last server used)
--  3. configuration

function Cli.configure (cli, arguments)
  assert (getmetatable (cli) == Cli)
  -- parse  the cmd line arguments to fetch server and/or color options
  for _, key in ipairs {  -- key to parse
    "server",
    "color",
  } do
    local pattern = "%-%-" .. key .. "=(.*)"
    local j = 1
    while j <= #arguments do
      local argument = arguments [j]
      local value = argument:match (pattern)   -- value contains only right hand side of equals
      if value then -- matched
        assert (not cli [key])  -- (better)  nil or false
        cli [key] = value
        table.remove (arguments, j)
      else
        j = j + 1
      end
    end
  end
  cli.arguments = arguments

  -- tell in which directory should the config be saved
  local directory  = Configuration.cli.directory
  Lfs.mkdir (directory)  -- in the case it does not exist already
  local data_file  = Configuration.cli.data
  -- reads the config
  local saved_config = File.decode (data_file) or {}
  if cli.server then -- save the server in the config file  ~/.cosy/cli.data
    saved_config.server = cli.server -- may override the server
    File.encode (data_file, saved_config)
  else -- try to fetch the server from the previously saved config
    if saved_config.server then
      cli.server = saved_config.server
    else -- try to fetch the server from the default config
      if Configuration.cli.server then
        cli.server = Configuration.cli.server  -- may override the server
        saved_config.server = cli.server
        File.encode (data_file, saved_config)
      end
    end
  end
  assert (cli.server)

  Loader.server = cli.server

  -- telecharger le nouveau loader
  local Http = require "socket.http"
  local body, status = Http.request (cli.server .. "/lua/cosy.loader.cli")
  if status ~= 200 then -- could not fetch loader
    return
  end  -- otherwise keep the same modules

  -- decharger tous les modules already loaded ( directly or by transitivity)
  for k in pairs (package.loaded) do
    if not loaded_modules [k] then
       package.loaded [k] = nil  -- unload every module that was not loaded at startup
    end
  end
  assert (loadstring (body)) ()  -- execute the loader
  init()   -- reloads locally every modules
end

function Cli.start (cli)
  assert (getmetatable (cli) == Cli)
  cli:configure (_G.arg)
  local daemondata = File.decode (Configuration.daemon.data)

  if not cli.color then
    Colors = function (s)
      return s:gsub ("(%%{(.-)})", "")
    end
  end

  local ws = Websocket.client.sync {
    timeout = 10,
  }
  if not daemondata
  or not ws:connect ("ws://{{{interface}}}:{{{port}}}/ws" % {
           interface = daemondata.interface,
           port      = daemondata.port,
         }, "cosy") then
    os.execute ([==[
      if [ -f "{{{pid}}}" ]
      then
        kill -9 $(cat {{{pid}}}) 2> /dev/null
      fi
      rm -f {{{pid}}} {{{log}}}
      luajit -e '_G.logfile = "{{{log}}}"; require "cosy.daemon" .start ()' &
    ]==] % {
      pid = Configuration.daemon.pid,
      log = Configuration.daemon.log,
    })
    local tries = 0
    repeat
      os.execute ([[sleep {{{time}}}]] % { time = 0.5 })
      daemondata = File.decode (Configuration.daemon.data)
      tries      = tries + 1
    until daemondata or tries == 5
    if not daemondata
    or not ws:connect ("ws://{{{interface}}}:{{{port}}}/ws" % {
             interface = daemondata.interface,
             port      = daemondata.port,
           }, "cosy") then
      print (Colors ("%{white redbg}" .. i18n ["failure"] % {}),
             Colors ("%{white redbg}" .. i18n ["daemon:unreachable"] % {}))
      os.exit (1)
    end
  end

  local Commands = require "cosy.commands"
  local commands = Commands.new (ws)
  local command  = commands [cli.arguments [1] or false]

  Cliargs:set_name (cli.arguments [0] .. " " .. cli.arguments [1])
  table.remove (cli.arguments, 1)

  local ok, result = xpcall (command, function ()
    print (Colors ("%{white redbg}" .. i18n ["error:unexpected"] % {}))
  --  print (Value.expression (e))
  --  print (debug.traceback ())
  end)
  if not ok then
    if result then
      print (Colors ("%{white redbg}" .. i18n (result.error).message))
    end
  end
  if result and result.success then
    os.exit (0)
  else
    os.exit (1)
  end
end

function Cli.stop (cli)
  assert (getmetatable (cli) == Cli)
end

return Cli
