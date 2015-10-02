#! /usr/bin/env lua

local lfs     = require "lfs"
local serpent = require "serpent"

local rockspec = {
  package = "cosyverif",
  version = "master-1",

  source = {
    url = "git://github.com/cosyverif/library",
  },

  description = {
    summary     = "CosyVerif",
    detailed    = [[]],
    homepage    = "http://www.cosyverif.org/",
    license     = "MIT/X11",
    maintainer  = "Alban Linard <alban@linard.fr>",
  },

  dependencies = {
    "ansicolors >= 1",
    "bcrypt >= 2",
    "bit32 >= 5",
    "copas-ev >= 0",
    "coronest >= 1",
    "dkjson >= 2",
    "hotswap >= 1",
    "i18n >= 0",
    "layeredata >= 0",
    "lua >= 5.1",
    "lua_cliargs >= 2",
    "lua-cjson >= 2",
    "lua-ev >= v1",
    "lua-geoip >= 0",
    "lua-websockets >= v2",
    "luacrypto >= 0",
    "luajwt >= 1",
    "luafilesystem >= 1",
    "lualogging >= 1",
    "luasec >= 0",
    "luasocket >= 2",
    "lustache >= 1",
    "redis-lua >= 2",
    "serpent >= 0",
  },

  build = {
    type    = "builtin",
    modules = {},
    install = {
      bin = {
        ["cosy"] = "src/cosy.lua",
      },
      conf = {},
    },
  },
}

local function resource (path)
  for content in lfs.dir (path) do
    local subpath = path .. "/" .. content
    if     lfs.attributes (subpath, "mode") == "file" then
      rockspec.build.install.conf [subpath:sub (#"src/")] = subpath
    elseif content ~= "." and content ~= ".."
    and    lfs.attributes (subpath, "mode") == "directory" then
      resource (subpath)
    end
  end
end

for module in lfs.dir "src/cosy/" do
  local path = "src/cosy/" .. module .. "/"
  if  module ~= "." and module ~= ".."
  and lfs.attributes (path, "mode") == "directory" then
    if lfs.attributes (path .. "init.lua", "mode") == "file" then
      rockspec.build.modules ["cosy." .. module] = path .. "init.lua"
      for submodule in lfs.dir (path) do
        if  submodule ~= "." and submodule ~= ".."
        and lfs.attributes (path .. submodule, "mode") == "file"
        and submodule:find "%.lua$" then
          submodule = submodule:sub (1, #submodule-4)
          rockspec.build.modules ["cosy." .. module .. "." .. submodule] = path .. submodule .. ".lua"
        end
      end
    else
      resource (path)
    end
  end
end

local options = {
  indent   = "  ",
  comment  = false,
  sortkeys = true,
  compact  = false,
  fatal    = true,
  nocode   = true,
  nohuge   = true,
}
lfs.mkdir "rockspec"
local file = io.open ("rockspec/cosyverif-master-1.rockspec", "w")
for _, key in ipairs {
  "package",
  "version",
  "source",
  "description",
  "dependencies",
  "build",
} do
  local output = serpent.block (rockspec [key], options)
  file:write (key .. " = " .. output .. "\n")
end
file:close ()
