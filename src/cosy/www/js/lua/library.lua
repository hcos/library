local location = js.global.location
coroutine      = require (location.origin .. "/lua/coroutine.make") ()
loader   = require (location.origin .. "/lua/cosy.loader")

local Actions = {}

function Actions.main ()
 return xpcall (function ()
lib      = loader.hotswap: require "cosy.js"
client   = lib.connect "http://127.0.0.1:8080/"
end, function (err)
    js.global.console:log ("error hotswap: " .. tostring (err))
    js.global.console:log (debug.traceback ())
  end)
end

function Actions.tos (callback)
  return xpcall (function ()

	local tostext  = client.tos ()
    callback (nil, tostext.tos)
    
  end, function (err)
    js.global.console:log ("error: " .. tostring (err))
    js.global.console:log (debug.traceback ())
  end)
end

function Actions.create_user (request)
  return xpcall (function ()
	local tostext  = client.tos ()
    
    local ok, result = pcall (client.create_user, {
   --[[username   = "alinard",
    password   = "password",
    email      = "alban.linard@gmail.com",--]]
	username   = request.username,
    password   = request.password,
    email      = request.email ,
    
    tos_digest = tostext.tos_digest:upper (),
    locale     = "en",
  })
    if ok then
    js.global:setResponse("create_user",result)
    else
    js.global:showError(result._)
    end
  end, function (err)
    js.global.console:log ("error: " .. tostring (err))
    js.global.console:log (debug.traceback ())
  end)
end

function Actions.authenticate (request)
  return xpcall (function ()
	local tostext  = client.tos ()  
    local ok, result = pcall (client.authenticate, {
	username   = request.username,
    password   = request.password,

  })
    if ok then
    js.global:setResponse("authenticate",result)
    else
    js.global:showError(result._)
    end
  end, function (err)
    js.global.console:log ("error: " .. tostring (err))
    js.global.console:log (debug.traceback ())
  end)
end
--[[
local actions_mt = {}
js.global.actions = setmetatable ({}, actions_mt)

function actions_mt:__index (k)
	local f = Actions [k]
	assert (f)
	return function (...)
		local co = coroutine.create(f)
		coroutine.resume (co, ...)
	end
end
--]]
 js.global.actions = js.new(js.global.Object)
 
for k, f in pairs (Actions) do
	 js.global.console:log (k .. tostring (f))
	 js.global.actions [k] = js.new (js.global.Object,function (_, ...)
		local co = coroutine.create (f)
		coroutine.resume (co, ...)
	end)
end
--js.global.actions = actions
 js.global.actions.main ()
