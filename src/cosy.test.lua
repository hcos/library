local cosy = require "cosy"

local model = cosy ["http://cosyverif.org/my-model"]
model.a = 1
local x = model.c
model.b = cosy ["http://cosyverif.org/other-model"].c
