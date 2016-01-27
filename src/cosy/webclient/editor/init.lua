return function (loader)

  local Webclient = loader.load "cosy.webclient"
  local I18n      = loader.load "cosy.i18n"
  local i18n      = I18n.load {}

  local Editor    = {}
  Editor.__index  = Editor
  Editor.template = Webclient.template "cosy.webclient.editor"

  function Editor.__call ()
    Webclient (function ()
      Webclient.show {
        where    = "main",
        template = Editor.template,
        data     = {},
        i18n     = i18n,
      }
    end)
  end

  return setmetatable ({}, Editor)

end
