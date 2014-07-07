local cosy = require "cosy.lang.cosy"
local tags = require "cosy.lang.tags"
local serpent = require "serpent"

local observed  = require "cosy.lang.view.observed"
observed [#observed + 1] = require "cosy.lang.view.update"
observed [#observed + 1] = require "cosy.lang.view.parent"

cosy [tags.NAME] = "cosy"

-- Cosy allows several models to be connected in the library. Updates should
-- be stored per model, and sent to the corresponding editor.

view = observed (cosy)
view.m1 = {}
view.m2 = {}
print (serpent.block (cosy))

view.m1.a = 1
view.m1.b = {}
view.m1.b [tags.TAG] = 1
view.m1.d = view.m1.b
print (serpent.block (cosy))

view.m2.c = { 1, 2, 3 }
view.m2 [view.m1.b] = view.m1.b
print (serpent.block (cosy))
