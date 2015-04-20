local hotswap = require "hotswap"

local Logger = {}

if _G.js then
  local logger = _G.js.global.console
  function Logger.debug (t)
    local i18n = hotswap "cosy.platform.i18n"
    logger:log ("DEBUG: " .. i18n (t))
  end
  function Logger.info (t)
    local i18n = hotswap "cosy.platform.i18n"
    logger:log ("INFO: " .. i18n (t))
  end
  function Logger.warning (t)
    local i18n = hotswap "cosy.platform.i18n"
    logger:log ("WARNING: " .. i18n (t))
  end
  function Logger.error (t)
    local i18n = hotswap "cosy.platform.i18n"
    logger:log ("ERROR: " .. i18n (t))
  end
else
  local logging   = hotswap "logging"
  logging.console = hotswap "logging.console"
  local logger    = logging.console "%message\n"
  function Logger.debug (t)
    local colors = hotswap "ansicolors"
    local i18n   = hotswap "cosy.platform.i18n"
    logger:debug (colors ("%{dim cyan}" .. i18n (t)))
  end
  function Logger.info (t)
    local colors = hotswap "ansicolors"
    local i18n   = hotswap "cosy.platform.i18n"
    logger:info (colors ("%{green}" .. i18n (t)))
  end
  function Logger.warning (t)
    local colors = hotswap "ansicolors"
    local i18n   = hotswap "cosy.platform.i18n"
    logger:warn (colors ("%{yellow}" .. i18n (t)))
  end
  function Logger.error (t)
    local colors = hotswap "ansicolors"
    local i18n   = hotswap "cosy.platform.i18n"
    logger:error (colors ("%{white redbg}" .. i18n (t)))
  end
end

return Logger