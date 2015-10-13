local Loader        = require "cosy.loader"
      Loader.nolog  = true
local Configuration = require "cosy.configuration"
local Value         = require "cosy.value"
local Lfs           = require "lfs"
local I18n          = require "cosy.i18n"
local Cliargs       = require "cliargs"
local Colors        = require "ansicolors"
local Websocket     = require "websocket"

Configuration.load {
  "cosy.cli",
  "cosy.daemon",
}

local i18n   = I18n.load {
  "cosy.cli",
  "cosy.commands",
  "cosy.daemon",
}
i18n._locale = Configuration.cli.locale

local Cli = {}

local function read (filename)
  local file = io.open (filename, "r")
  if not file then
    return nil
  end
  local data = file:read "*all"
  file:close ()
  return Value.decode (data)
end


function Cli.start ()
  local directory  = Configuration.cli.directory
  Lfs.mkdir (directory)
  
  local daemondata = read (Configuration.daemon.data)
  
  if _G.arg [1] == "--no-color" then
    _G.nocolor = true
    table.remove (_G.arg, 1)
  end
  
  if _G.nocolor then
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
      daemondata = read (Configuration.daemon.data)
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
  local command  = commands [_G.arg [1] or false]
  
  Cliargs:set_name (_G.arg [0] .. " " .. _G.arg [1])
  table.remove (_G.arg, 1)
  
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
