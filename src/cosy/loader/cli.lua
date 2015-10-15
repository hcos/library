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

io.stdout:setvbuf "no"

local Loader = {}

package.preload ["cosy.loader"] = function ()
  return Loader
end


Loader.scheduler = require "copas"
Loader.nolog     = true
Loader.hotswap   = require "hotswap" .new {}
Loader.loadhttp = (require "socket.http").request


local Ltn12 = require "ltn12"

-- read the file that lists of packages to download
local Lfs = require "lfs"
local File = require "cosy.file"

local Configuration = require "cosy.configuration"
Configuration.load {
  "cosy.cli",
}
local packages_data = File.decode (Configuration.cli.packages_data) or {}

local function http_require (name)
  -- print ("http_require ",name, Loader.server)
  if not Loader.server then
    return nil
  end
  local url = Loader.server .. "/lua/" .. name
  local parts = {}
  local _, status, headers = Loader.loadhttp {
    url = url,
    method = "GET",
    headers = {
      ["If-None-Match"] = packages_data [name],
    },
    sink = Ltn12.sink.table(parts) -- how to store the result
  }
  local result
  -- eg ~/.cosy/lua/cosy.x.lua for both cosy/x/init.lua   or  cosy/x.lua
  local local_filename = Configuration.cli.packages_directory .. "/" .. name .. ".lua"
  -- print ("fetching module ",name, "status ", status, "local_filename", local_filename)
  if status == 200 then -- OK
    local content = table.concat (parts)
    if File.encode (local_filename, content) then
      packages_data [name] = headers.etag
    end
    result = loadstring (content)
  elseif status == 304 then
    result = loadfile (local_filename)
  else
    packages_data [name] =  nil  -- remove element
  end
  File.encode (Configuration.cli.packages_data, packages_data )
  -- print (" local_filename",local_filename, " result=",result)
  return result
end

table.insert (package.searchers, 2, http_require) -- installs package searcher
_G.require = Loader.hotswap.require



Lfs.mkdir (Configuration.cli.packages_directory)

-- parse the packages file
for name in pairs (packages_data) do
  require (name)  -- reload
end




                 require "cosy.string"
local Coromake = require "coroutine.make"
_G.coroutine   = Coromake ()

return Loader
