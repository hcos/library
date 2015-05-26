local Configuration = require "cosy.configuration"
local Value         = require "cosy.value"

local Commands = {}

local function read (filename)
  local file = io.open (filename, "r")
  if not file then
    return nil
  end
  local data = file:read "*all"
  file:close ()
  return Value.decode (data)
end

Commands ["daemon:stop"] = {
  _   = "cli:daemon:stop",
  run = function (cli, ws)
    local args = cli:parse_args ()
    if not args then
      os.exit (1)
    end
    return ws:send (Value.expression "daemon-stop")
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
      os.exit (1)
    end
    if args.clean then
      local Redis     = require "redis"
      local host      = Configuration.redis.interface._
      local port      = Configuration.redis.port._
      local database  = Configuration.redis.database._
      local client    = Redis.connect (host, port)
      client:select (database)
      client:flushdb ()
      package.loaded ["redis"] = nil
    end
    return os.execute ([[
      luajit -e 'require "cosy.server" .start ()' &
    ]] % { --  > %{log} 2>&1
      log = Configuration.server.log_file._,
    })
  end,
}
Commands ["server:stop"] = {
  _   = "cli:server:stop",
  run = function (cli, ws)
    local args = cli:parse_args ()
    if not args then
      os.exit (1)
    end
    local serverdata = read (Configuration.server.data_file._)
    ws:send (Value.expression {
      server     = "http://%{interface}:%{port}" % {
        interface = serverdata.interface,
        port      = serverdata.port,
      },
      operation  = "stop",
      parameters = {
        token = serverdata.token,
      },
    })
    local result = ws:receive ()
    return Value.expression (result)
  end,
}

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
  run = function (cli, ws)
    addoptions (cli)
    local args = cli:parse_args ()
    if not args then
      os.exit (1)
    end
    ws:send (Value.expression {
      server     = args.server,
      operation  = "information",
      parameters = {
        locale = args.locale,
      },
    })
    local result = ws:receive ()
    return Value.decode (result)
  end,
}

Commands ["show:tos"] = {
  _   = "cli:tos",
  run = function (cli, ws)
    addoptions (cli)
    local args = cli:parse_args ()
    if not args then
      os.exit (1)
    end
    ws:send (Value.expression {
      server     = args.server,
      operation  = "tos",
      parameters = {
        locale = args.locale,
      },
    })
    local result = ws:receive ()
    return Value.decode (result)
  end,
}

return Commands
