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
end

-- Cosy.models [url] = {
--   [VALUE] = <model>
--   username = ...
--   password = ...
--   resource = ...
--   editor   = ...
--   editor.token = ...
-- }
--

function Platform.new (meta)
  return setmetatable ({
    meta = meta,
  }, Platform)
end

function Platform:close ()
end

local Tags = require "cosy.tags"
local TYPE     = Tags.TYPE
local INSTANCE = Tags.INSTANCE
local VISIBLE  = Tags.VISIBLE

local Algorithm = require "cosy.algorithm"

local function visible_types (x)
  return Algorithm.filter (x, function (d)
    return d [TYPE] () == true and d [VISIBLE] () == true
  end)
end

local function visible_instances (x)
  return Algorithm.filter (x, function (d)
    return d [INSTANCE] () == true and d [VISIBLE] () == true
  end)
end

function instantiate (target_type, data)
  
end

function create (source, link_type, target_type, data)
  
end

function delete (target)
  
end

return Platform
