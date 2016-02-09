local Arguments = require "argparse"
local Lfs       = require "lfs"
local Serpent   = require "serpent"
local Lustache  = require "lustache"
local Metatable = getmetatable ""

Metatable.__mod = function (pattern, variables)
  return Lustache:render (pattern, variables)
end

local parser = Arguments () {
  name        = "cosy-rockspec",
  description = "cosy rockspec generator",
}
parser:option "-s" "--source" {
  description = "path to cosy source",
  default     = "./src",
}
parser:option "-t" "--target" {
  description = "path to rockspec directory",
  default     = (os.getenv "PWD") .. "/rockspec",
}
local arguments = parser:parse ()

local rockspecs = {
  full = {
    package = "cosy",
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
      "lua >= 5.2",
      "cosy-client",
      "amalg",
      "ansicolors",
      "argparse",
      "bcrypt",
      "copas-ev",
      "coronest",
      "dkjson",
      "hotswap",
      "hotswap-ev",
      "hotswap-http",
      "i18n",
      "jwt",
      "layeredata",
      "lua-cjson-ol", -- needed by jwt, instead of lua-cjson
      "lua-ev",
      "lua-resty-http",
      "lua-websockets",
      "luacrypto",
      "luafilesystem",
      "lualogging",
      "luaposix",
      "luasec",
      "luasocket",
      "lustache",
      "md5",
      "serpent",
    },
    build = {
      type    = "builtin",
      modules = {},
      install = {
        bin = {
          ["cosy-server"  ] = "src/cosy/server/bin.lua",
          ["cosy-check"   ] = "src/cosy/check/bin.lua",
          ["cosy-rockspec"] = "src/cosy/rockspec/bin.lua",
        },
        conf = {},
      },
      copy_directories = {
        arguments.source .. "/cosy",
      },
    },
  },
  client = {
    package = "cosy-client",
    version = "master-1",
    source = {
      url = "git://github.com/cosyverif/library",
    },
    description = {
      summary     = "CosyVerif Client",
      detailed    = [[]],
      homepage    = "http://www.cosyverif.org/",
      license     = "MIT/X11",
      maintainer  = "Alban Linard <alban@linard.fr>",
    },
    dependencies = {
      "lua >= 5.2",
      "ansicolors",
      "argparse",
      "copas",
      "coronest",
      "hotswap",
      "hotswap-http",
      "i18n",
      "layeredata",
      "lua-cjson",
      "lua-websockets",
      "luacrypto",
      "luafilesystem",
      "lualogging",
      "luasec",
      "luasocket",
      "lustache",
    },
    build = {
      type    = "builtin",
      modules = {},
      install = {
        bin = {
          ["cosy"     ] = "src/cosy/client/bin.lua",
          ["cosy-tool"] = "src/cosy/tool/bin.lua",
        },
      },
    },
  },
}

local modules   = {}
local resources = {}

local function find (path, prefix)
  for module in Lfs.dir (path) do
    local subpath = path .. "/" .. module
    if  module ~= "." and module ~= ".."
    and Lfs.attributes (subpath, "mode") == "directory" then
      if Lfs.attributes (subpath .. "/init.lua", "mode") == "file" then
        modules [prefix .. "." .. module] = subpath .. "/init.lua"
      end
      local subprefix = prefix .. "." .. module
      for submodule in Lfs.dir (subpath) do
        if  submodule ~= "." and submodule ~= ".."
        and Lfs.attributes (subpath .. "/" .. submodule, "mode") == "file"
        and not submodule:find "init%.lua$"
        and not submodule:find "bin%.lua$"
        then
          if submodule:match "%.lua$" then
            submodule = submodule:sub (1, #submodule-4)
            modules [subprefix .. "." .. submodule] = subpath .. "/" .. submodule .. ".lua"
          else
            resources [#resources+1] = subpath .. "/" .. submodule
          end
        elseif Lfs.attributes (subpath .. "/" .. submodule, "mode") == "directory" then
          find (subpath, subprefix)
        end
      end
    end
  end
end

find (arguments.source .. "/cosy", "cosy")
rockspecs.client.build.modules = modules

local options = {
  indent   = "  ",
  comment  = false,
  sortkeys = true,
  compact  = false,
  fatal    = true,
  nocode   = true,
  nohuge   = true,
}

Lfs.mkdir (arguments.target)
do
  local file = io.open (arguments.target .. "/cosy-master-1.rockspec", "w")
  for _, key in ipairs {
    "package",
    "version",
    "source",
    "description",
    "dependencies",
    "build",
  } do
    local output = Serpent.block (rockspecs.full [key], options)
    file:write (key .. " = " .. output .. "\n")
  end
  file:close ()
end
do
  local file = io.open (arguments.target .. "/cosy-client-master-1.rockspec", "w")
  for _, key in ipairs {
    "package",
    "version",
    "source",
    "description",
    "dependencies",
    "build",
  } do
    local output = Serpent.block (rockspecs.client [key], options)
    file:write (key .. " = " .. output .. "\n")
  end
  file:close ()
end
