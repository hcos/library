-- Overall Configuration
-- =====================

-- This module returns an object describing the overall configuration.
-- It tries to load files named `cosy.json` or `cosy.yaml` located in directories
-- listed in `Platform.configuration.paths` (in order).
--
-- All the found configurations are merged to obtain the result. It allows to
-- preset some configuration variables system-wide.

local Platform  = require "cosy.platform"

local Metatable = {}
local Configuration = setmetatable ({}, Metatable)

-- This function imports the `source` table inside the `target` one.
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

Metatable.__index = Metatable

function Metatable.reload ()
  for k in pairs (Configuration) do
    if k ~= "reload" then
      Configuration [k] = nil
    end
  end
  for _, path in ipairs (Platform.configuration.paths) do
    local found = false
    for name, loader in pairs {
      ["cosy.yaml"] = Platform.yaml.decode,
      ["cosy.json"] = Platform.json.decode,
    } do
      local content = Platform.configuration.read (path .. "/" .. name)
      if content then
        -- If a directory contains both `cosy.json` and `cosy.yaml` files, an error is raised
        -- as there is no way to known which one should be used.
        if found then
          Platform.logger.error {
            "configuration:conflict",
            path = path,
          }
          error "Invalid configuration"
        end
        import (loader (content), Configuration)
        found = true
        Platform.logger.debug {
          "configuration:using",
          path = path,
        }
      end
    end
  end
end

Configuration:reload ()

return Configuration