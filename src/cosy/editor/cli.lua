local arguments
do
  local loader        = require "cosy.loader.lua" {
    logto = false,
  }
  local Configuration = loader.load "cosy.configuration"
  local I18n          = loader.load "cosy.i18n"
  local Token         = loader.load "cosy.token"
  local Arguments     = loader.require "argparse"

  Configuration.load {
    "cosy.editor",
    "cosy.server",
  }

  local i18n   = I18n.load {
    "cosy.editor",
  }
  i18n._locale = Configuration.server.locale

  local parser = Arguments () {
    name        = "cosy-editor",
    description = i18n ["editor:command"] % {},
  }
  parser:option "-a" "--alias" {
    description = i18n ["editor:alias"] % {},
    default     = "default",
  }
  parser:option "-t" "--token" {
    description = i18n ["editor:token"] % {},
    default     = Token.authentication {},
  }
  parser:argument "resource" {
    description = i18n ["editor:resource"] % {},
    convert     = function (s)
      assert (s:match "^https?://")
      return s
    end,
  }
  arguments = parser:parse ()
end

local Scheduler = require "copas.ev"
local Hotswap   = require "hotswap.ev".new {
  loop = Scheduler._loop,
}
local loader    = require "cosy.loader.lua" {
  alias     = arguments.alias,
  logto     = false,
  hotswap   = Hotswap,
  scheduler = Scheduler,
}
local Editor    = loader.load "cosy.editor"

Editor.start (arguments)
