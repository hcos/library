local location = js.global.location
local loader    = require (location.origin .. "/lua/cosy.loader")

local profile = function  ()
  local value   = require "cosy.value"
  local co = coroutine.running ()
  local storage = js.global.sessionStorage
  local token = storage:getItem("cosytoken")
  local username = storage:getItem("cosyuser")
  js.global.document:getElementById("content-wrapper").innerHTML = loader.loadhttp ( "/html/profile.html")

  local result, err = client.user.information {
        user   = username
        }
  if result then
  js.global.document:getElementById("username").value = result.username
  js.global.document:getElementById("name").value = result.name
  js.global.document:getElementById("home").value = result.homepage
  js.global.document:getElementById("org").value = result.organization
  print ( value.expression (result))

  else 
  
  end
  js.global.document:getElementById("update").onclick = function()
     coroutine.resume(co,"update")
     return false
  end
  
  local ok = true
  while ok do
    local event = coroutine.yield ()
    if event == "update" then
      local user  = js.global.document:getElementById("username").value
      local email  = js.global.document:getElementById("email").value
    --  local avatar  = client.server.tos ()
    
      local result, err = client.user.create {
      username   = user,
      password   = pass,
      email      = email ,
      tos_digest = tostext.tos_digest:upper (),
      locale     = "en",
      }

     if result then
        window:jQuery('#success #message'):html("User Created")
        window:jQuery('#success'):show()
      else
        window:jQuery('#error #message'):html(err.message)
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
