local _          = require "cosy.util.string"
local ignore     = require "cosy.util.ignore"
local logging   = require "logging"
logging.console = require "logging.console"

local logger = logging.console "%level %message\n"

local Platform = {}

Platform.__index = Platform

function Platform:log (message)
  ignore (self)
  logger:debug (message)
end

function Platform:info (message)
  ignore (self)
  logger:info (message)
end

function Platform:warn (message)
  ignore (self)
  logger:warn (message)
end

function Platform:error (message)
  ignore (self)
  logger:error (message)
end

function Platform:send (message)
  ignore (self, message)
end

function Platform.new (meta)
  return setmetatable ({
    meta = meta,
  }, Platform)
end

function Platform:close ()
  ignore (self)
end

return Platform
