local cosy = require "cosy" . cosy

local model = cosy ["http://cosyverif.org/my-model"]
model.a = 1
local _ = model.c
model.b = cosy ["http://cosyverif.org/other-model"].c
