local Platform   = require "cosy.platform"
local Repository = require "cosy.repository"

local repository = Repository.new ()
Repository.options (repository).create = function () end
Repository.options (repository).import = function () end

repository.internal = {}
repository.default  = require "cosy.configuration.default"

local loaded = {
  repository.internal,
  repository.default,
  nil, -- required for 100% code coverage :-(
}
for _, path in ipairs (Platform.configuration.paths) do
  local filename = path .. "/cosy.conf"
  local content  = Platform.configuration.read (filename)
  if content then
    if pcall (function ()
      content = Platform.value.decode (content)
      repository [filename] = t
      loaded [#loaded+1] = repository [filename]
    end) then
      Platform.logger.debug {
        _    = "configuration:using",
        path = path,
      }
    else
      Platform.logger.warn {
        _      = "configuration:skipping",
        path   = path,
        reason = t,
      }
    end
  end
end
repository.whole = {
  [Repository.depends] = loaded,
}

return repository.whole