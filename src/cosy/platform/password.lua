local hotswap = require "hotswap"

if _G.js then
  error "Not available"
end

local Password = {}

local function compute_rounds ()
  local bcrypt        = hotswap "bcrypt"
  local time          = hotswap "cosy.platform.time"
  local configuration = hotswap "cosy.platform.configuration"
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

function Password.hash (password)
  local bcrypt = hotswap "bcrypt"
  return bcrypt.digest (password, Password.rounds)
end

function Password.verify (password, digest)
  local bcrypt = hotswap "bcrypt"
  return bcrypt.verify (password, digest)
end

function Password.is_too_cheap (digest)
  return tonumber (digest:match "%$%w+%$(%d+)%$") < Password.rounds
end

do
  local logger        = hotswap "cosy.platform.logger"
  local configuration = hotswap "cosy.platform.configuration"
  compute_rounds ()
  logger.debug {
    _     = "platform:bcrypt-rounds",
    count = Password.rounds,
    time  = configuration.data.password.time._ * 1000,
  }
end

return Password