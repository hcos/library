-- These lines are required to correctly run tests:
require "cosy.loader.busted"
require "busted.runner" ()

local File = require "cosy.file"

describe ("Module cosy.file", function ()
  randomize (false)  --  tells to play the test in that given order
  --   the first test creates a file and the second test needs that file

  local expected_data
  local filename

  setup (function ()
    filename = os.tmpname ()
    expected_data = {
      "First line.",
    }
 end)

  it ("should save data into a file", function ()
    File.encode (filename, expected_data)
  end)

  it ("should read data from a file", function ()
    local result_data = File.decode (filename)
    assert.are.same (expected_data, result_data)
  end)

  it ("should fail by trying to read a non existing file", function ()
    os.remove (filename)
    assert.has.errors (function ()
      File.decode (filename)
    end)
  end)

  it ("should return nil when reading an empty file", function ()
    local file = io.open (filename, "w")
    file:close ()
    assert.is_nil (File.decode (filename))
  end)

end)
