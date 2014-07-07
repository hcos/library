local cosy = require "cosy.lang.cosy"
cosy.tags  = require "cosy.lang.tags"

local observed  = require "cosy.lang.view.observed"
observed [#observed + 1] = require "cosy.lang.view.update"
observed [#observed + 1] = require "cosy.lang.view.parent"

-- Cosy allows several models to be connected in the library. Updates should
-- be stored per model.

cosy.models = {
  { url     = "",
    editor  = "",
    updates = "",
  }
}
