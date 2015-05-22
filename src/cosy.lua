#! /usr/bin/env luajit

local Loader        = require "cosy.loader"
      Loader.nolog  = true
local Configuration = require "cosy.configuration"
local Lfs           = require "lfs"
local Socket        = require "socket"
      Socket.unix   = require "socket.unix"
local Cli           = require "cliargs"
local I18n          = require "cosy.i18n"
local Colors        = require "ansicolors"
local Commands      = require "cosy.commands"

local directory  = Configuration.config.directory._
Lfs.mkdir (directory)

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
    for j = #line, name_size+12 do
      line = line .. " "
    end
    line = line .. "%{yellow}" .. list [names [i]]
    print (Colors (line))
  end
  os.exit (1)
end

local socketfile = Configuration.config.daemon.socket_file._
if Lfs.attributes (socketfile, "mode") ~= "socket" then
  local oldarg = _G.arg
  _G.arg = {
    [0] = "daemon:start",
  }
  os.execute ([[
    luajit -e 'require "cosy.daemon" .start ()' &
  ]] % { --  > %{log} 2>&1
    log = Configuration.config.daemon.log_file._,
  })
  _G.arg = oldarg
end

Cli:set_name (_G.arg [0] .. " " .. _G.arg [1])
table.remove (_G.arg, 1)
command.run (Cli)
