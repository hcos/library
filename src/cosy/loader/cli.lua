--- When starting Cli (re)-loads the packages from the server
---      every package has a timestamp & validity duration

-- Cli gets the loader from the server
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

Loader.loadhttp = function (url)
  local request = (require "socket.http").request
  local body, status = request (url)
  return body, status
end

Loader.scheduler = require "copas"
Loader.hotswap   = require "hotswap" .new {}
Loader.nolog     = true

table.insert (package.searchers, 2, function (name)
  if not Loader.server then
    return nil
  end
  local url = Loader.server .. "/lua/" .. name
  local result, err
  result, err = Loader.loadhttp (url)
  if not result then
    error (err)
  end
  return load (result, url)
end)

                 require "cosy.string"
local Coromake = require "coroutine.make"
_G.coroutine   = Coromake ()

--[[
-- tell in which directory should the config be saved
local directory  = Configuration.cli.directory
Lfs.mkdir (directory)  -- in the case it does not exist already
local data_file  = Configuration.cli.data
-- reads the config
local saved_config = File.decode (data_file) or {}
--]]

return Loader
