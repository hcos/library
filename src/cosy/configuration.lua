local Platform  = require "cosy.platform"

local function read (path, loader)
  local handle = io.open (path, "r")
  if handle ~=nil then
    local content = handle:read "*all"
    io.close (handle)
    return loader (content)
  else
    return nil
  end
end

local function import (source, target)
  assert (type (source) == "table")
  assert (type (target) == "table")
  for k, v in pairs (source) do
    if type (v) == "table" then
      if target [k] == nil then
        target [k] = v
      else
        import (v, target [k])
      end
    else
      target [k] = v
    end
  end
end

local Configuration = {}
for _, path in ipairs {
  "/etc",
  os.getenv "HOME" .. "/.cosy",
  os.getenv "PWD",
} do
  for name, loader in pairs {
    ["cosy.yaml"] = Platform.yaml.decode,
    ["cosy.json"] = Platform.json.decode,
  } do
    local loaded = read (path .. "/" .. name, loader)
    if loaded then
      import (Configuration, loaded)
      Platform.logger:debug ("Configured using '${path}'." % {
        path = path,
      })
    end
  end
end

return Configuration
