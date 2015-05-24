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
    Daemon.update ()
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
    local Daemon = require "cosy.daemon"
    Daemon.stop ()
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
    local Server = require "cosy.server"
    Server.update ()
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
    local Server = require "cosy.server"
    Server.stop ()
  end,
}

local Value  = require "cosy.value"

local function addoptions (cli)
  cli:add_option (
    "-s, --server=SERVER",
    "",
    Configuration.cli.default_server._
  )
  cli:add_option (
    "-l, --locale=LOCALE",
    "",
    Configuration.cli.default_locale._
  )
end

Commands ["show:information"] = {
  _   = "cli:information",
  run = function (cli)
    addoptions (cli)
    local args = cli:parse_args ()
    if not args then
      cli:print_help ()
      os.exit (1)
    end
    local Daemon = require "cosy.daemon"
    local answer = Daemon {
      server    = args.server,
      operation = "information",
    }
    print (Value.expression (answer))
  end,
}

Commands ["show:tos"] = {
  _   = "cli:tos",
  run = function (cli)
    addoptions (cli)
    local args = cli:parse_args ()
    if not args then
      cli:print_help ()
      os.exit (1)
    end
    local Daemon = require "cosy.daemon"
    local answer = Daemon {
      server    = args.server,
      operation = "tos",
    }
    print (Value.expression (answer))
  end,
}

return Commands
