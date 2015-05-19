#! /usr/bin/env lua

-- Default values for the program options:
local defaults = {}

local loader  = require "cosy.loader"
local cli     = loader "cliargs"

cli:set_name (arg [0])

cli:add_option (
  "-c, --clean",
  "clean redis database"
)

local args = cli:parse_args ()

if not args then
  cli:print_help ()
  os.exit (1)
end

if args.clean then
  local redis     = loader "redis"
  local host      = loader.configuration.redis.host._
  local port      = loader.configuration.redis.port._
  local database  = loader.configuration.redis.database._
  local client = redis.connect (host, port)
  client:select (database)
  client:flushdb ()
  package.loaded.redis = nil
end

loader.server.start ()
