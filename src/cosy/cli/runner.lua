local Cli = require "cosy.cli"

local cli = Cli.new ()
local ok, err = pcall (cli.start, cli)
if not ok then
  print ("An error happened. Maybe the client was unable to download sources from " .. (cli.server or "no server") .. ".")
  local errorfile = os.tmpname ()
  local file      = io.open (errorfile, "w")
  file:write (tostring (err))
  file:close ()
  print ("See error file " .. errorfile .. " for more information.")
  os.exit (1)
end
