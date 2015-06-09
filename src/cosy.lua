#! /usr/bin/env luajit

local Loader        = require "cosy.loader"
      Loader.nolog  = true
local Configuration = require "cosy.configuration"
local Value         = require "cosy.value"
local Lfs           = require "lfs"
local Cli           = require "cliargs"
local I18n          = require "cosy.i18n"
local Colors        = require "ansicolors"
local Websocket     = require "websocket"

Configuration.load "cosy"
Configuration.load "cosy.daemon"

local i18n   = I18n.load "cosy"
i18n._locale = Configuration.cli.default_locale._

local directory  = Configuration.cli.directory._
Lfs.mkdir (directory)

local Commands = require "cosy.commands"
local command = Commands [arg [1] or false]

if not command then
  local name_size = 0
  local names     = {}
  local list      = {}
  for name, c in pairs (Commands) do
    name_size = math.max (name_size, #name)
    names [#names+1] = name
    list [name] = I18n (c)
  end
  print (Colors ("%{white redbg}" .. i18n ["command:missing"] % {
    cli    = arg [0],
  }))
  print (i18n ["command:available"] % {})
  table.sort (names)
  for i = 1, #names do
    local line = "  %{green}" .. names [i]
    for _ = #line, name_size+12 do
      line = line .. " "
    end
    line = line .. "%{yellow}" .. list [names [i]]
    print (Colors (line))
  end
  os.exit (1)
end

local function read (filename)
  local file = io.open (filename, "r")
  if not file then
    return nil
  end
  local data = file:read "*all"
  file:close ()
  return Value.decode (data)
end
local daemondata = read (Configuration.daemon.data_file._)

local ws = Websocket.client.sync {
  timeout = 5,
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
    pid = Configuration.daemon.pid_file._,
    log = Configuration.daemon.log_file._,
  })
  local tries = 0
  repeat
    os.execute ([[sleep {{{time}}}]] % { time = 0.5 })
    daemondata = read (Configuration.daemon.data_file._)
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

Cli:set_name (_G.arg [0] .. " " .. _G.arg [1])
table.remove (_G.arg, 1)
local result = command.run (Cli, ws)
if result.success then
  os.exit (0)
else
  os.exit (1)
end

