return function (loader)

  local I18n          = loader.load "cosy.i18n"
  local Scheduler     = loader.load "cosy.scheduler"
  local Webclient     = loader.load "cosy.webclient"

  local i18n = I18n.load {
    "cosy.webclient.profile",
    "cosy.webclient.authentication",
    "cosy.client",
  }
  i18n._locale = Webclient.window.navigator.language

  local Profile = {
    template = {},
  }
  Profile.__index = Profile
  Profile.template.show = Webclient.template "cosy.webclient.profile.show"
  Profile.template.edit = Webclient.template "cosy.webclient.profile.edit"

  local function check (info, t)
    Webclient.jQuery "#accept":addClass "disabled"
    local email        = Webclient.jQuery "#email":val ()
    local name         = Webclient.jQuery "#name":val ()
    local organization = Webclient.jQuery "#organization":val ()
    local homepage     = Webclient.jQuery "#homepage":val ()
    local password     = Webclient.jQuery "#password-1":val ()
    local result, err  = Webclient.client.user.update ({
      email        = email        ~= (info.email        or "") and email        or nil,
      avatar       = t.avatar                                  and t.avatar     or nil,
      name         = name         ~= (info.name         or "") and name         or nil,
      organization = organization ~= (info.organization or "") and organization or nil,
      homepage     = homepage     ~= (info.homepage     or "") and homepage     or nil,
      password     = password     ~= ""                        and password     or nil,
      position     = t.position                                and t.position   or nil,
      locale       = Webclient.locale,
    }, {
      try_only = true,
    })
    for _, x in ipairs { "avatar", "name", "organization", "email", "homepage", "position" } do
      Webclient.jQuery ("#" .. x .. "-group"):removeClass "has-error"
      Webclient.jQuery ("#" .. x .. "-error"):html ""
      if  Webclient.jQuery ("#" .. x):val () ~= info [x] then
        Webclient.jQuery ("#" .. x .. "-group"):addClass "has-success"
      end
    end
    for _, x in ipairs { "password-1", "password-2" } do
      Webclient.jQuery ("#" .. x .. "-group"):removeClass "has-error"
      Webclient.jQuery ("#" .. x .. "-error"):html ""
      if  Webclient.jQuery ("#" .. x):val () ~= "" then
        Webclient.jQuery ("#" .. x .. "-group"):addClass "has-success"
      end
    end
    if t.position then
      Webclient.jQuery "#position-group":addClass "has-success"
    end
    local passwords = {
      Webclient.jQuery "#password-1":val (),
      Webclient.jQuery "#password-2":val (),
    }
    if passwords [1] ~= passwords [2] then
      Webclient.jQuery "#password-group":addClass "has-error"
      local text = i18n ["argument:password:nomatch"] % {}
      Webclient.jQuery "#password-error":html (text)
      result = false
    end
    if result then
      Webclient.jQuery "#accept":removeClass "disabled"
      return true
    elseif err then
      for _, reason in ipairs (err.reasons or {}) do
        Webclient.jQuery ("#" .. reason.key .. "-group"):addClass "has-error"
        Webclient.jQuery ("#" .. reason.key .. "-error"):html (reason.message)
      end
      return false
    end
  end

  function Profile.__call (options)
    Webclient (function ()
      local co   = Scheduler.running ()
      local user = Webclient.client.user.authentified_as {}
      options.username = options.username or user.identifier
      if user and options.username == user.identifier then
        local t = {
          username = options.username or user.identifier,
          position = nil,
          avatar   = nil,
        }
        local info = Webclient.client.user.update {}
        Webclient.show {
          where    = "main",
          template = Profile.template.edit,
          data     = info,
          i18n     = i18n,
        }
        if not info.position and Webclient.navigator.geolocation then
          Webclient.navigator.geolocation:getCurrentPosition (function (_, p)
            info.position = {
              latitude  = p.coords.latitude,
              longitude = p.coords.longitude,
            }
            Scheduler.wakeup (co)
          end)
          Scheduler.sleep (-math.huge)
        end
        Webclient.jQuery "#position":locationpicker (Webclient.tojs {
          location     = info.position,
          radius       = 0,
          inputBinding = {
            locationNameInput = Webclient.jQuery "#address",
          },
          enableAutocomplete = true,
          onchanged          = function ()
            local location = Webclient.jQuery "#position":locationpicker "map".location
            t.position = {
              address   = location.formattedAddress,
              latitude  = location.latitude,
              longitude = location.longitude,
            }
            Webclient (check, info, t)
          end,
          oninitialized      = function ()
            local location = Webclient.jQuery "#position":locationpicker "map".location
            t.position = {
              address   = location.formattedAddress,
              latitude  = location.latitude,
              longitude = location.longitude,
            }
            Webclient (check, info, t)
          end,
        })
        while true do
          for _, x in ipairs { "name", "organization", "homepage", "email", "password-1", "password-2" } do
            Webclient.jQuery ("#" .. x):focusout (function ()
              Webclient (check, info, t)
            end)
          end
          Webclient.jQuery "#avatar-button":change (function ()
            local reader = Webclient.js.new (Webclient.window.FileReader)
            reader.onload = function ()
              Webclient.jQuery "#avatar":attr ("src", reader.result)
              t.avatar = reader.result:match "base64,(.*)"
              Webclient (check, info, t)
            end
            local button = Webclient.jQuery "#avatar-button"
            reader:readAsDataURL (button:prop "files" [0])
          end)
          Webclient.jQuery "#accept":click (function ()
            Scheduler.wakeup (co)
            return false
          end)
          Webclient.jQuery "#delete":click (function ()
            Webclient.jQuery "bootbox":confirm (i18n ["profile:delete"] % {}, function (result)
              if result ~= Webclient.js.null then
                Webclient (function ()
                  Webclient.jQuery "#delete":html [[<i class="fa fa-spinner fa-pulse"></i>]]
                  assert (Webclient.client.user.delete {})
                  Webclient.jQuery "#log-out":click ()
                end)
              end
            end)
            return false
          end)
          Scheduler.sleep (-math.huge)
          local email        = Webclient.jQuery "#email":val ()
          local name         = Webclient.jQuery "#name":val ()
          local organization = Webclient.jQuery "#organization":val ()
          local homepage     = Webclient.jQuery "#homepage":val ()
          local password     = Webclient.jQuery "#password-1":val ()
          Webclient.jQuery "#accept":html [[<i class="fa fa-spinner fa-pulse"></i>]]
          assert (Webclient.client.user.update {
            email        = email        ~= (info.email        or "") and email        or nil,
            avatar       = t.avatar                                  and t.avatar     or nil,
            name         = name         ~= (info.name         or "") and name         or nil,
            organization = organization ~= (info.organization or "") and organization or nil,
            homepage     = homepage     ~= (info.homepage     or "") and homepage     or nil,
            password     = password     ~= ""                        and password     or nil,
            position     = t.position                                and t.position   or nil,
            locale       = Webclient.locale,
          })
          Webclient.jQuery "#accept":html [[<i class="fa fa-edit"></i>]]
          Webclient.jQuery "#accept":addClass "disabled"
        end
      else
        local info = Webclient.client.user.information {
          user = options.username,
        }
        Webclient.show {
          where    = "main",
          template = Profile.template.show,
          data     = info,
          i18n     = i18n,
        }
        Webclient.jQuery "#position":locationpicker (Webclient.tojs {
          location     = info.position,
          radius       = 0,
        })
      end
    end)
  end

  return setmetatable ({}, Profile)

end
