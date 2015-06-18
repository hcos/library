local location = js.global.location
local loader    = require (location.origin .. "/lua/cosy.loader")

local profile = function  ()
  local value   = require "cosy.value"
  local co = coroutine.running ()
  local storage = js.global.sessionStorage
  local token = storage:getItem("cosytoken")
  local username = storage:getItem("cosyuser")
  js.global.document:getElementById("content-wrapper").innerHTML = loader.loadhttp ( "/html/profile.html")

  local result, err = client.user.update {
    authentication = token
    }
  
  if result then
  js.global.document:getElementById("pusername").innerHTML = result.username
  js.global.document:getElementById("name").value = result.name
  js.global.document:getElementById("email").value = result.email

  js.global.document:getElementById("home").value = result.homepage
  js.global.document:getElementById("org").value = result.organization
  js.global.document:getElementById("lang").value = result.locale
  js.global.document:getElementById("city").value = result.position.city
  
  else 
    print ( value.expression (err))

  end
  js.global.document:getElementById("update").onclick = function()
     coroutine.resume(co,"update")
     return false
  end
  
  local ok = true
  while ok do
    local event = coroutine.yield ()
    if event == "update" then
    
      local email  = js.global.document:getElementById("email").value

    --  local avatar  = client.server.tos ()
      local homepage  = js.global.document:getElementById("home").value
      local organization  = js.global.document:getElementById("org").value
      local locale  = js.global.document:getElementById("lang").value
      local name  = js.global.document:getElementById("name").value

      local position = {
            city = js.global.document:getElementById("city").value,
            country =  js.global.document:getElementById("country").value,
            latitude  = "",
            longitude = "",
            }
            print (token)

      local result, err = client.user.update {
      authentication = token,
      email         = email,
      homepage      = homepage,
      organization  = organization,
      name          = name,
      locale        = locale,
      position      = position,

      }

     if result then
        window:jQuery('#success #message'):html("User Profile Updated")
        window:jQuery('#success'):show()
      else
        window:jQuery('#error #message'):html(value.expression(err))
        window:jQuery('#error'):show()
        if err.reasons then
          for i = 1, #err.reasons do
            local reason = err.reasons [i]
            if reason.parameter == "username" then
              window:jQuery('#usererror'):html(reason.message)
              window:jQuery('#usererror'):show()
              window:jQuery('#userdiv'):addClass("has-error")
            elseif reason.parameter == "email" then
              window:jQuery('#emailerror'):html(reason.message)
              window:jQuery('#emailerror'):show()
              window:jQuery('#emaildiv'):addClass("has-error")
            end
          end
        end
      end
    end
  end
end


local co = coroutine.create (profile)
coroutine.resume (co)
