local loader  = require "cosy.loader"
local hotswap = loader.hotswap

if _G.js then
  error "Not available"
end

local Password = {}

--[[
local function compute_rounds ()
  local bcrypt        = hotswap "bcrypt"
  local time          = loader.time
  local configuration = loader.configuration
  for _ = 1, 5 do
    local rounds = 5
    while true do
      local start = time ()
      bcrypt.digest ("some random string", rounds)
      local delta = time () - start
      if delta > configuration.data.password.time._ then
        Password.rounds = math.max (Password.rounds or 0, rounds)
        break
      end
      rounds = rounds + 1
    end
  end
  return Password.rounds
end
--]]

function Password.hash (password)
--  local bcrypt = hotswap "bcrypt"
--  return bcrypt.digest (password, Password.rounds)
  return loader.digest (password)
end

function Password.verify (password, digest)
--  local bcrypt = hotswap "bcrypt"
--  return bcrypt.verify (password, digest)
  return loader.digest (password) == digest
end

function Password.is_too_cheap (digest)
  return false
--  return tonumber (digest:match "%$%w+%$(%d+)%$") < Password.rounds
end

--[[
do
  local logger        = loader.logger
  local configuration = loader.configuration
  compute_rounds ()
  logger.debug {
    _     = "bcrypt:rounds",
    count = Password.rounds,
    time  = configuration.data.password.time._ * 1000,
  }
end
--]]

return Password