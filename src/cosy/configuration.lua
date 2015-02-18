-- Overall Configuration
-- =====================

-- This module returns an object describing the overall configuration.
-- It tries to load files named `cosy.json` or `cosy.yaml` located in directories
-- listed in `Platform.configuration.paths` (in order).
--
-- All the found configurations are merged to obtain the result. It allows to
-- preset some configuration variables system-wide.

local Platform = require "cosy.platform"
local Data     = require "cosy.data"

local Configuration = Data.as_table (Data.new ())

Configuration.internal = {}
Configuration.default  = require "cosy.configuration.default"

do
  local loaded = {
    Configuration.internal,
    Configuration.default,
  }
  for _, path in ipairs (Platform.configuration.paths) do
    local found = false
    for name, loader in pairs {
      ["cosy.yaml"] = Platform.yaml.decode,
      ["cosy.json"] = Platform.json.decode,
    } do
      local filename = path .. "/" .. name
      local content  = Platform.configuration.read (filename)
      if content then
        -- If a directory contains both `cosy.json` and `cosy.yaml` files,
        -- an error is raised as there is no way to known which one
        -- should be used.
        if found then
          Platform.logger.error {
            "configuration:conflict",
            path = path,
          }
          error "Invalid configuration"
        end
        Configuration [filename] = loader (content)
        loaded [#loaded+1] = Configuration [filename]
        Platform.logger.debug {
          "configuration:using",
          path = path,
        }
        found = true
      end
    end
  end
  Configuration.whole = {
    [Data.DEPENDS] = loaded,
  }
end

return Configuration