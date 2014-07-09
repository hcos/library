local global = _ENV or _G

global.cosy = {}
global.cosy.tags = require "cosy.lang.tags"

local cosy = global.cosy
local NAME = cosy.tags.NAME

cosy [NAME] = "cosy"
NAME.persistent = true

return cosy
