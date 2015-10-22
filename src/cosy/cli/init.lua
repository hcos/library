require "cosy.loader.cli"

local Configuration = require "cosy.configuration"
local File          = require "cosy.file"
local I18n          = require "cosy.i18n"
local Lfs           = require "lfs"
local Cliargs       = require "cliargs"
local Colors        = require "ansicolors"
local Websocket     = require "websocket"

Configuration.load {
  "cosy.cli",
  "cosy.daemon",
}

local i18n   = I18n.load {
  "cosy.cli",
  "cosy.daemon",
}
i18n._locale = Configuration.cli.locale

local Cli = {
  color = true,
}

-----------------------------
--  While not found Cli tries to determine what server it will connect to
--    by scanning in that order :
--  1. --server=xxx   cmd line option
--  2. ~/.cosy/cli.data config file (ie last server used)
--  3. configuration

function Cli.configure (arguments)
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
        assert (not Cli [key])  -- (better)  nil or false
        Cli [key] = value
        table.remove (arguments, j)
      else
        j = j + 1
      end
    end
  end
  Cli.arguments = arguments

  -- tell in which directory should the config be saved
  local directory  = Configuration.cli.directory
  Lfs.mkdir (directory)  -- in the case it does not exist already
  local data_file  = Configuration.cli.data
  -- reads the config
  local saved_config = File.decode (data_file) or {}
  if Cli.server then -- save the server in the config file  ~/.cosy/cli.data
    saved_config.server = Cli.server -- may override the server
    File.encode (data_file, saved_config)
  else -- try to fetch the server from the previously saved config
    if saved_config.server then
      Cli.server = saved_config.server
    else -- try to fetch the server from the default config
      if Configuration.cli.server then
        Cli.server = Configuration.cli.server  -- may override the server
        saved_config.server = Cli.server
        File.encode (data_file, saved_config)
      end
    end
  end
  assert (Cli.server)
end

function Cli.start ()
  Cli.configure (_G.arg)
  local daemondata = File.decode (Configuration.daemon.data)

  if not Cli.color then
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

  local Commands = require "cosy.cli.commands"
  local commands = Commands.new (ws)
  local command  = commands [Cli.arguments [1] or false]

  Cliargs:set_name (Cli.arguments [0] .. " " .. Cli.arguments [1])
  table.remove (Cli.arguments, 1)

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

function Cli.stop ()
end

return Cli
