#! /usr/bin/env lua

-- Default values for the program options:
local defaults = {}

local loader  = require "cosy.loader"
local cli     = loader "cliargs"

cli:set_name (arg [0])
local args = cli:parse_args ()
if not args then
  cli:print_help ()
  os.exit (1)
end

loader.server.start ()
