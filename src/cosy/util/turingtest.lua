local Platform = require "cosy.platform"

local TuringTest = {}

TuringTest.questions = {}

function TuringTest.generate ()
  math.randomseed (os.time ())
  local i = math.random (1, #TuringTest)
  return TuringTest [i] ()
end

TuringTest [1] = function ()
  return {
    question = Platform.i18n "turing:what-is-round",
    answer   = function (x) return x:trim ():lower () == "place" end
  }
end

TuringTest [1] = function ()
  return {
    question = Platform.i18n "turing:what-is-rectangular",
    answer   = function (x) return x:trim ():lower () == Platform.i18n "transition" end
  }
end

setmetatable (TuringTest, { __call = TuringTest.generate })

return TuringTest