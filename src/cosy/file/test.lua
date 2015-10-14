-- These lines are required to correctly run tests:
require "cosy.loader.busted"
require "busted.runner" ()

local File = require "cosy.file"

describe ("Module cosy.file", function ()
-------------------------- commented randomize that is not recognized by luacheck tool
--------------------------   adapted tests so that they can be passed in any order
--  randomize (false)  --  tells to play the test in that given order
  --   the first test creates a file and the second test needs that file

  local expected_data
  local filename

  before_each (function ()
   filename = os.tmpname ()
   expected_data = {
     "First line.",
   }
  end)
  after_each (function ()
    os.remove( filename )
  end)

  it ("should save then read data into a file", function ()
    File.encode (filename, expected_data)
    local result_data = File.decode (filename)
    assert.are.same (expected_data, result_data)
  end)

  it ("should fail by trying to read a non existing file", function ()
    os.remove( filename )
    local data, err = File.decode (filename)
    assert.is_nil (data)
    print(err)
    assert.is_not_nil (err)
  end)

  it ("should return nil when reading an empty file", function ()
    local file = io.open (filename, "w")
    file:close ()
    local data, err = File.decode (filename)
    assert.is_nil (data)
    assert.is_nil (err)
  end)

end)
