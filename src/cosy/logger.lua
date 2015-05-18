local loader  = require "cosy.loader"

local Logger = {}

if _G.js then
  local logger = _G.js.global.console
  function Logger.debug (t)
    local i18n = loader.i18n
    logger:log ("DEBUG: " .. i18n (t))
  end
  function Logger.info (t)
    local i18n = loader.i18n
    logger:log ("INFO: " .. i18n (t))
  end
  function Logger.warning (t)
    local i18n = loader.i18n
    logger:log ("WARNING: " .. i18n (t))
  end
  function Logger.error (t)
    local i18n = loader.i18n
    logger:log ("ERROR: " .. i18n (t))
  end
else
  local logging   = loader "logging"
  logging.console = loader "logging.console"
  local logger    = logging.console "%message\n"
  local colors    = loader "ansicolors"
  local i18n      = loader.i18n
  function Logger.debug (t)
    logger:debug (colors ("%{dim cyan}" .. i18n (t)))
  end
  function Logger.info (t)
    logger:info (colors ("%{green}" .. i18n (t)))
  end
  function Logger.warning (t)
    logger:warn (colors ("%{yellow}" .. i18n (t)))
  end
  function Logger.error (t)
    logger:error (colors ("%{white redbg}" .. i18n (t)))
  end
end

return Logger