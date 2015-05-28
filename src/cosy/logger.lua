local Loader = require "cosy.loader"
local I18n   = require "cosy.i18n"
local Logger = {}

if _G.js then
  local logger = _G.window.console
  function Logger.debug (t)
    logger:log ("DEBUG: "   .. I18n (t))
  end
  function Logger.info (t)
    logger:log ("INFO: "    .. I18n (t))
  end
  function Logger.warning (t)
    logger:log ("WARNING: " .. I18n (t))
  end
  function Logger.error (t)
    logger:log ("ERROR: "   .. I18n (t))
  end
elseif Loader.nolog then
  function Logger.debug   () end
  function Logger.info    () end
  function Logger.warning () end
  function Logger.error   () end
elseif Loader.logfile then
  local logging   = require "logging"
                    require "logging.file"
  local logger    = logging.file (Loader.logfile, "%Y-%m-%d")
  function Logger.debug (t)
    logger:debug (I18n (t))
  end
  function Logger.info (t)
    logger:info  (I18n (t))
  end
  function Logger.warning (t)
    logger:warn  (I18n (t))
  end
  function Logger.error (t)
    logger:error (I18n (t))
  end
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