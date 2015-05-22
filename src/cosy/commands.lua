local Configuration = require "cosy.configuration"

local Commands = {}

Commands ["daemon:update"] = {
  _   = "cli:daemon:update",
  run = function (cli)
    local args = cli:parse_args ()
    if not args then
      cli:print_help ()
      os.exit (1)
    end
    local Daemon = require "cosy.daemon"
    local socket = require "socket.unix" ()
    socket:connect (Configuration.config.daemon.socket_file._)
    socket:send (Daemon.Messages.update .. "\n")
    socket:close ()
  end,
}
Commands ["daemon:stop"] = {
  _   = "cli:daemon:stop",
  run = function (cli)
    local args = cli:parse_args ()
    if not args then
      cli:print_help ()
      os.exit (1)
    end
    local Daemon      = require "cosy.daemon"
    local Socket      = require "socket"
          Socket.unix = require "socket.unix"
    local socket      = Socket.unix ()
    socket:connect (Configuration.config.daemon.socket_file._)
    socket:send (Daemon.Messages.stop .. "\n")
    socket:close ()
  end,
}

Commands ["server:start"] = {
  _   = "cli:server:start",
  run = function (cli)
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
      local Redis     = require "redis"
      local host      = Configuration.redis.host._
      local port      = Configuration.redis.port._
      local database  = Configuration.redis.database._
      local client    = Redis.connect (host, port)
      client:select (database)
      client:flushdb ()
      package.loaded ["redis"] = nil
    end
    os.execute ([[
      luajit -e 'require "cosy.server" .start ()' &
    ]] % { --  > %{log} 2>&1
      log = Configuration.config.server.log_file._,
    })
  end,
}
Commands ["server:update"] = {
  _   = "cli:server:update",
  run = function (cli)
    local args = cli:parse_args ()
    if not args then
      cli:print_help ()
      os.exit (1)
    end
    local Server      = require "cosy.server"
    local Socket      = require "socket"
          Socket.unix = require "socket.unix"
    local socket      = Socket.unix ()
    socket:connect (Configuration.config.server.socket_file._)
    socket:send (Server.Messages.update .. "\n")
    socket:close ()
  end,
}
Commands ["server:stop"] = {
  _   = "cli:server:stop",
  run = function (cli)
    local args = cli:parse_args ()
    if not args then
      cli:print_help ()
      os.exit (1)
    end
    local Server      = require "cosy.server"
    local Socket      = require "socket"
          Socket.unix = require "socket.unix"
    local socket      = Socket.unix ()
    socket:connect (Configuration.config.server.socket_file._)
    socket:send (Server.Messages.stop .. "\n")
    socket:close ()
  end,
}

return Commands
