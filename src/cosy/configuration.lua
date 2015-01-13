local Platform  = require "cosy.platform"

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
for _, path in ipairs (Platform.configuration.paths) do
  for name, loader in pairs {
    ["cosy.yaml"] = Platform.yaml.decode,
    ["cosy.json"] = Platform.json.decode,
  } do
    local content = Platform.configuration.read (path .. "/" .. name)
    if content then
      import (Configuration, loader (content))
      Platform.logger:debug ("Configured using '${path}'." % {
        path = path,
      })
    end
  end
end

return Configuration
