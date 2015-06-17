local location = js.global.location
local loader    = require (location.origin .. "/lua/cosy.loader")

local function main()
  local lib      = require "cosy.library"
  client   = lib.connect (js.global.location.origin) 

  local storage = js.global.sessionStorage
  local token = storage:getItem("cosytoken")
  local user = storage:getItem("cosyuser")
  local connected = false
  if token ~= js.null then
    connected = true
  end
  if connected then
    js.global.document:getElementById("navbar-login").innerHTML = loader.loadhttp ( "/html/logoutnavbar.html")
    js.global.document:getElementById("user-in").innerHTML = user
    js.global.document:getElementById("logout-button").onclick = function()
      storage:removeItem("cosytoken")
      storage:removeItem("cosyuser")
      js.global.location.href = "/"
      return false
    end  
    js.global.document:getElementById("profile-button").onclick = function()
      require ("cosy.webclient.profile")  
      return false
    end    
  else
    local auth = require ("cosy.webclient.auth") 
    js.global.document:getElementById("navbar-login").innerHTML = loader.loadhttp ( "/html/loginnavbar.html")
    js.global.document:getElementById("login-button").onclick = function()
      coroutine.wrap(auth.login) ()
      return false
    end
    js.global.document:getElementById("signup-button").onclick = function()
      coroutine.wrap(auth.register) ()  
      return false
    end
  end
  
end

local co = coroutine.create (main)
coroutine.resume (co)
