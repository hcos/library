--- When starting Cli (re)-loads the packages from the server
---      every package has a timestamp & validity duration

-- Cli gets the hotswap loader from the server
-- Cli loader asks the list & eTag of the packages
-- Cli removes the packages "suppressed by the server"
-- Cli updates the outdated packages (before updating them)
-- Cli sends in parallel as many requests as there are packages to download
-- Cli stores into ~/.cosy/lua the packages downloaded from server
-- Cli stores into ~/.cosy/lua.data file the table that contains eTag for every package
--
------------- 5.1 package.loaders -->  5.2 package.searchers  loader.cli.lua
-- Cli insert in its searchers at 2n position in its package.searchers table
--
---- Configuration
-- Default.cli = {
--   packages_directory = os.getenv "HOME" .. "/.cosy/lua",
--   packages_data = os.getenv "HOME" .. "/.cosy/lua.data",
-- }
if #setmetatable ({}, { __len = function () return 1 end }) ~= 1
then
  error "Cosy requires Lua >= 5.2 or Luajit with 5.2 compatibility to run."
end

local Loader = {}

package.preload ["cosy.loader"] = function ()
  return Loader
end

Loader.scheduler = require "copas"
Loader.nolog     = true
Loader.loadhttp = (require "socket.http").request

                  require "cosy.string"
local Coromake = require "coroutine.make"
_G.coroutine   = Coromake ()

return Loader
