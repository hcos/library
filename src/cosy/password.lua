local loader  = require "cosy.loader"

if _G.js then
  error "Not available"
end

local Password = {}

local function compute_rounds ()
  local bcrypt        = loader.hotswap "bcrypt"
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

function Password.hash (password)
  local bcrypt = loader.hotswap "bcrypt"
  return bcrypt.digest (password, Password.rounds)
end

function Password.verify (password, digest)
  local bcrypt = loader.hotswap "bcrypt"
  if not bcrypt.verify (password, digest) then
    return false
  end
  if tonumber (digest:match "%$%w+%$(%d+)%$") < Password.rounds then
    return Password.hash (password)
  end
  return true
end

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

return Password