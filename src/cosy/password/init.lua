if _G.js then
  error "Not available"
end

return function (loader)

  local Configuration = loader.load "cosy.configuration"
  local I18n          = loader.load "cosy.i18n"
  local Logger        = loader.load "cosy.logger"
  local Time          = loader.require "socket".gettime
  local Bcrypt        = loader.require "bcrypt"

  Configuration.load "cosy.password"

  local i18n   = I18n.load "cosy.password"
  i18n._locale = Configuration.locale

  local Password = {}

  local function compute_rounds ()
    for _ = 1, 5 do
      local rounds = 5
      while true do
        local start = Time ()
        Bcrypt.digest ("some random string", rounds)
        local delta = Time () - start
        if delta > Configuration.password.time then
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
      _      = i18n ["bcrypt:rounds"],
      rounds = Password.rounds,
      time   = Configuration.password.time * 1000,
    }
  end

  return Password

end
