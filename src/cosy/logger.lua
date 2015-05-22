local Loader = require "cosy.loader"
local I18n   = require "cosy.i18n"
local Logger = {}

if _G.js then
  local logger = _G.js.global.console
  function Logger.debug (t)
    local i18n = I18n
    logger:log ("DEBUG: " .. i18n (t))
  end
  function Logger.info (t)
    local i18n = I18n
    logger:log ("INFO: " .. i18n (t))
  end
  function Logger.warning (t)
    local i18n = I18n
    logger:log ("WARNING: " .. i18n (t))
  end
  function Logger.error (t)
    local i18n = I18n
    logger:log ("ERROR: " .. i18n (t))
  end
elseif Loader.nolog then
  function Logger.debug   () end
  function Logger.info    () end
  function Logger.warning () end
  function Logger.error   () end
else
  local logging   = require "logging"
  logging.console = require "logging.console"
  local logger    = logging.console "%message\n"
  local colors    = require "ansicolors"
  function Logger.debug (t)
    logger:debug (colors ("%{dim cyan}"    .. I18n (t)))
  end
  function Logger.info (t)
    logger:info (colors ("%{green}"        .. I18n (t)))
  end
  function Logger.warning (t)
    logger:warn (colors ("%{yellow}"       .. I18n (t)))
  end
  function Logger.error (t)
    logger:error (colors ("%{white redbg}" .. I18n (t)))
  end
end

return Logger