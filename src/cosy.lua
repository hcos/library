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

local directory  = Configuration.cli.directory._
Lfs.mkdir (directory)

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
  timeout = 1,
}
if not daemondata
or not ws:connect ("ws://%{interface}:%{port}/ws" % {
         interface = daemondata.interface,
         port      = daemondata.port,
       }, "cosy") then
  os.execute ([==[
    if [ -f "%{pid}" ]
    then
      kill -9 $(cat %{pid})
    fi
    rm -f %{pid} %{log}
    luajit -e '_G.logfile = "%{log}"; require "cosy.daemon" .start ()' &
    sleep 2
  ]==] % {
    pid = Configuration.daemon.pid_file._,
    log = Configuration.daemon.log_file._,
  })
  daemondata = read (Configuration.daemon.data_file._)
  if not ws:connect ("ws://%{interface}:%{port}/ws" % {
           interface = daemondata.interface,
           port      = daemondata.port,
         }, "cosy") then
    print (Colors ("%{white redbg}" .. I18n {
      _      = "daemon:unreachable",
      locale = Configuration.cli.default_locale._,
    }))
    os.exit (1)
  end
end

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
  print (Colors ("%{white redbg}" .. I18n {
    _   = "cli:missing-command",
    cli = arg [0],
  }))
  print (I18n {
    _   = "cli:available-commands",
  })
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

Cli:set_name (_G.arg [0] .. " " .. _G.arg [1])
table.remove (_G.arg, 1)
local result = command.run (Cli, ws)
if type (result) == "boolean" then
  if result then
    print (Colors ("%{green}" .. "success"))
  else
    print (Colors ("%{white redbg}" .. "failure"))
  end
elseif type (result) == "table" then
  if result.success then
    print (Colors ("%{green}" .. "success"))
    if type (result.response) == "table" then
      for k, v in pairs (result.response) do
        print (k, "=>", v)
      end
    else
      print (result.response)
    end
  else
    print (Colors ("%{white redbg}" .. I18n (result.error)))
  end
end
