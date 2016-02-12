local Lfs       = require "lfs"
local Lustache  = require "lustache"
local Colors    = require 'ansicolors'
local Arguments = require "argparse"
local Serpent   = require "serpent"

local parser = Arguments () {
  name        = "cosy-heroku",
  description = "Generate configuration",
}
parser:option "where" {
  description = "directory where the configuration will be",
  default     = os.getenv "PWD",
}

local arguments = parser:parse ()

local string_mt = getmetatable ""

function string_mt.__mod (pattern, variables)
  return Lustache:render (pattern, variables)
end

if Lfs.attributes (arguments.where, "mode") ~= "directory" then
  print (Colors ("%{bright red blackbg}failure%{reset}"))
  os.exit (1)
end

local configuration = {
  dev_mode  = false,
  recaptcha = {
    public_key  = os.getenv "RECAPTCHA_PUBLIC_KEY",
    private_key = os.getenv "RECAPTCHA_PRIVATE_KEY",
  },
}

local file = io.open (arguments.where .. "/cosy.conf", "w")
file:write (Serpent.dump (configuration))
file:close ()

print (Colors ("%{bright green blackbg}success%{reset}"))
os.exit (0)
