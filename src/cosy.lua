#! /usr/bin/env lua

package.path = package.path:gsub ("'", "")
  .. ";/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua;"
local loader = require "cosy.loader"
local cli    = require "cliargs"

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

do
  local internal    = loader.repository.of (loader.configuration) .internal
  local main        = package.searchpath ("cosy", package.path)
  if main:sub (1, 1) == "." then
    local lfs = loader "lfs"
    main = lfs.currentdir () .. "/" .. main
  end
  internal.http.www = main:sub (1, #main-4) .. "/../www/"
end

loader.server.start ()
