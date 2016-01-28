return function (loader)

  local Lfs     = loader.require "lfs"
  local Default = loader.load "cosy.configuration.layers".default

  local www = loader.prefix .. "/lib/luarocks/rocks/cosyverif/"
  for subpath in Lfs.dir (www) do
    if  subpath ~= "." and subpath ~= ".."
    and Lfs.attributes (www .. "/" .. subpath, "mode") == "directory" then
      www = www .. subpath .. "/src/cosy/www"
      break
    end
  end
  assert (www:match "/www$")

  Default.http = {
    nginx         = loader.prefix .. "/nginx",
    hostname      = nil,
    interface     = "*",
    port          = 8080,
    timeout       = 5,
    pid           = loader.home .. "/nginx.pid",
    configuration = loader.home .. "/nginx.conf",
    directory     = loader.home .. "/nginx",
    www           = www,
    www_fallback  = loader.prefix .. "/share/cosy/www",
    bundle        = loader.source .. "/cosy-full.lua",
  }

end
