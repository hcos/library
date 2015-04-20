local loader     = require "cosy.loader"

local Value      = loader.value
local Logger     = loader.logger
local Repository = loader.repository
local repository = Repository.new ()

Repository.options (repository).create = function () return {} end
Repository.options (repository).import = function () return {} end

repository.internal = {
  locale = "en",
}

repository.whole = {
  [Repository.depends] = {
    repository.internal,
    repository.default,
    repository.etc,
    repository.home,
    repository.pwd,
  },
}

local files = {
  default = nil,
  etc     = "/etc/cosy.conf",
  home    = os.getenv "HOME" .. "/.cosy/cosy.conf",
  pwd     = os.getenv "PWD" .. "/cosy.conf",
}

do -- fill the `default` path:
  local hotswap      = require "hotswap" .new ()
  repository.default = hotswap "cosy.configuration.default"
  files.default      = hotswap.sources ["cosy.configuration.default"]
end

if not _G.js then
  local scheduler = loader.scheduler
  scheduler.addthread (function ()
    scheduler.blocking (false)
    local co      = coroutine.running ()
    local ev      = require "ev"
    local hotswap = require "hotswap" .new ()
    hotswap.register = function (filename, f)
      ev.Stat.new (function ()
        f ()
        scheduler:wakeup (co)
      end, filename):start (scheduler._loop)
    end
    while true do
      for key, filename in pairs (files) do
        local ok, err  = pcall (function ()
          local handle  = io.open (filename, "r")
          if not handle then
            error "file does not exist"
          end
          local content    = handle:read "*all"
          content          = Value.decode (content)
          repository [key] = content
          io.close (handle)
        end)
        if ok then
          Logger.debug {
            _      = "configuration:using",
            path   = filename,
            locale = repository.whole.locale._,
          }
        else
          Logger.warning {
            _      = "configuration:skipping",
            path   = filename,
            reason = err,
            locale = repository.whole.locale._,
          }
        end
      end
      scheduler.sleep (-math.huge)
    end
  end)
  scheduler.loop ()
end

return repository.whole
