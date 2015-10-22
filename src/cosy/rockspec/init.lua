local Lfs     = require "lfs"
local Serpent = require "serpent"

-- Compute path:
local main = package.searchpath ("cosy.rockspec", package.path)
if main:sub (1, 2) == "./" then
  main = Lfs.currentdir () .. "/" .. main:sub (3)
end
main = main:gsub ("/rockspec/init.lua", "")

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
    "hotswap-ev >= 1",
    "hotswap-http >= 1",
    "i18n >= 0",
    "jwt >= 0",
    "layeredata >= 0",
    "lua >= 5.1",
    "lua_cliargs >= 2",
    "lua-cjson >= 2",
    "lua-ev >= v1",
    "lua-resty-http >= 0",
    "lua-websockets >= v2",
    "luacrypto >= 0",
    "luafilesystem >= 1",
    "lualogging >= 1",
    "luasec >= 0",
    "luasocket >= 2",
    "lustache >= 1",
    "md5 >= 1",
    "redis-lua >= 2",
    "Serpent >= 0",
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
  for content in Lfs.dir (path) do
    local subpath = path .. "/" .. content
    if     Lfs.attributes (subpath, "mode") == "file" then
      rockspec.build.install.conf [#rockspec.build.install.conf+1] = "src/cosy/" .. subpath:sub (#main+2)
    elseif content ~= "." and content ~= ".."
    and    Lfs.attributes (subpath, "mode") == "directory" then
      resource (subpath)
    end
  end
end

for module in Lfs.dir (main) do
  local path = main .. "/" .. module
  if  module ~= "." and module ~= ".."
  and Lfs.attributes (path, "mode") == "directory" then
    if Lfs.attributes (path .. "/init.lua", "mode") == "file" then
      rockspec.build.modules ["cosy." .. module] = "src/" .. module .. "/init.lua"
      for submodule in Lfs.dir (path) do
        if  submodule ~= "." and submodule ~= ".."
        and Lfs.attributes (path .. "/" .. submodule, "mode") == "file"
        and submodule:find "%.lua$" then
          submodule = submodule:sub (1, #submodule-4)
          rockspec.build.modules ["cosy." .. module .. "." .. submodule] = "src/" .. module .. "/" .. submodule .. ".lua"
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
local file = io.open ("cosyverif-master-1.rockspec", "w")
for _, key in ipairs {
  "package",
  "version",
  "source",
  "description",
  "dependencies",
  "build",
} do
  local output = Serpent.block (rockspec [key], options)
  file:write (key .. " = " .. output .. "\n")
end
file:close ()
