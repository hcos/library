if _G.js then
  error "Not available"
end

local Configuration = require "cosy.configuration"
local Logger        = require "cosy.logger"
local Time          = require "cosy.time"
local Bcrypt        = require "bcrypt"

local Password = {}

local function compute_rounds ()
  for _ = 1, 5 do
    local rounds = 5
    while true do
      local start = Time ()
      Bcrypt.digest ("some random string", rounds)
      local delta = Time () - start
      if delta > Configuration.data.password.time._ then
        Password.rounds = math.max (Password.rounds or 0, rounds)
        break
      end
      rounds = rounds + 1
    end
  end
  return Password.rounds
end

function Password.hash (password)
  return Bcrypt.digest (password, Password.rounds)
end

function Password.verify (password, digest)
  if not Bcrypt.verify (password, digest) then
    return false
  end
  if tonumber (digest:match "%$%w+%$(%d+)%$") < Password.rounds then
    return Password.hash (password)
  end
  return true
end

do
  compute_rounds ()
  Logger.debug {
    _     = "bcrypt:rounds",
    count = Password.rounds,
    time  = Configuration.data.password.time._ * 1000,
  }
end

return Password