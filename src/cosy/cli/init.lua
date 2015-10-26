local Cli = {
  color = true,
}

Cli.__index = Cli

function Cli.new ()
  return setmetatable ({}, Cli)
end

-----------------------------
--  While not found Cli tries to determine what server it will connect to
--    by scanning in that order :
--  1. --server=xxx   cmd line option
--  2. ~/.cosy/cli.data config file (ie last server used)
--  3. configuration

function Cli.configure (cli, arguments)
  assert (getmetatable (cli) == Cli)

  local _       = require "copas"  ---- WARNING WE CANNOT WAIT TO GET IT FROM THE SERVER
  local Lfs     = require "lfs"  -- C module : won't be reloaded from server
  local Json    = require "cjson"  -- lua tables are transcoded into json for server  (pkg comes with lua socket)
  local Ltn12   = require "ltn12"  -- to store the content of the requests ( pkgcomes with lua socket)
  local Mime    = require "mime"
  local Hotswap = require "hotswap.http"

  -- parse  the cmd line arguments to fetch server and/or color options
  local key = "server"
  local pattern = "%-%-" .. key .. "=(.*)"
  local j = 1
  while j <= #arguments do
    local argument = arguments [j]
    local value = argument:match (pattern)   -- value contains only right hand side of equals
    if value then -- matched
      assert (not cli [key])  -- (better)  nil or false
      cli [key] = value
      table.remove (arguments, j)
    else
      j = j + 1
    end
  end
  cli.arguments = arguments

  -- reads the config
  local cosy_dir   = os.getenv "HOME" .. "/.cosy"
  local data_file  = cosy_dir  .. "/cli-server" -- contains last server uri
  if not cli.server then ---- try to fetch the server from the previously saved config
    local file = io.open (data_file,"r")
    if file then
        cli.server  = file:read "*all"  -- all the file
        file:close ()
    end
  end
  if not cli.server then ---- still not :  -- try to fetch the server from the default config
    cli.server = "http://public.cosyverif.lsv.fr"
    cli.hardcoded_server = true -- warning
  end
  assert (cli.server)
  -- trim eventuel trailing /   http://server/
  cli.server  = cli.server:gsub("/+$","")
  assert (cli.server:match "^https?://")  -- check is an URI

  do -- save server name for next cli launch
    Lfs.mkdir (cosy_dir)
    local file, err = io.open (data_file,"w")
    if file then
      file:write (cli.server)
      file:close ()
    else
      print (err)
    end
  end -- save server name for next cli launch

-- hot_swap_http  (  storage_dir , cache)

  --  every dowloaded lua package will be saved in ~/.cosy/lua/base64(server_name)
  local package_dir = cosy_dir .. "/lua/"
  local server_dir  = package_dir .. Mime.b64 (cli.server)
  Lfs.mkdir (package_dir)
  Lfs.mkdir (server_dir)

  local hotswap = Hotswap {
    storage = server_dir, -- where to save the lua files
    encode = function (t)
      local data = Json.encode (t)
      return {
        url     = cli.server .. "/luaset",
        method  = "POST",
        headers = {
          ["Content-Length"] = #data,
        },
        source  = Ltn12.source.string (data),
      }
    end,
    decode = function (t)
      if t.code == 200 then
        return Json.decode (t.body)
      end
    end,
  }

-- In order to download lua modules (required by the client) from the server
-- we replace the Lua require function
--      by the hotswap.require which will also save lua packages into "server_dir"
  cli.loader = hotswap.require "cosy.loader.lua" {
    hotswap = hotswap,
    logto   = os.getenv "HOME" .. "/.cosy/client.log",
  }
 -- no module to download
 end

function Cli.start (cli)
  assert (getmetatable (cli) == Cli)

  cli:configure (_G.arg)
  local loader = cli.loader

  local Configuration = loader.load "cosy.configuration"
  local App           = loader.load "cosy.configuration.layers".app
  local File          = loader.load "cosy.file"
  local I18n          = loader.load "cosy.i18n"
  local Library       = loader.load "cosy.library"
  local Arguments     = loader.require "argparse"
  local Colors        = loader.require "ansicolors"
  local Websocket     = loader.require "websocket"

  Configuration.load {
    "cosy.cli",
  }
  App.cli = {
    server = cli.server,
  }
  local i18n = I18n.load {
    "cosy.cli",
  }
  i18n._locale = Configuration.cli.locale

  local client = Library.connect (cli.server)
  if not client then
    print (Colors ("%{white redbg}" .. i18n ["failure"] % {}),
           Colors ("%{white redbg}" .. i18n ["server:unreachable"] % {}))
    os.exit (1)
  end

  local name = os.getenv "COSY_PREFIX" .. "/bin/cosy"
  name = name:gsub (os.getenv "HOME", "~")
  local parser = Arguments () {
    name        = name,
    description = i18n ["client:command"] % {},
  }
  parser:option "-s" "--server" {
    description = i18n ["option:server"] % {},
    default     = cli.server,
  }
  parser:option "-l" "--locale" {
    description = i18n ["option:locale"] % {},
    default     = Configuration.cli.locale,
  }

  local Commands = loader.load "cosy.cli.commands"
  local commands = Commands.new {
    parser = parser,
    client = client,
  }
  local command = commands [cli.arguments [1] or false]

  local ok, result = xpcall (command, function ()
    print (Colors ("%{white redbg}" .. i18n ["error:unexpected"] % {}))
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

function Cli.stop (cli)
  assert (getmetatable (cli) == Cli)
end

return Cli
