local Cli = require "cosy.cli"

local cli = Cli.new ()
local ok, err = pcall (cli.start, cli)
if not ok then
  print ("An error happened: " .. err)
  print ("Maybe the client was unable to download sources from " .. cli.server .. ".")
  os.exit (1)
end
