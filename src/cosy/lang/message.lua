-- Message Handlers
-- ================

-- Error and warning should not be implemented as "exceptions" or using the
-- Lua `error` function, because several errors or warnings can occur and
-- all of them should be reported to the user or developer, not only the
-- first one. Exceptions break the execution and thus prevent to easily
-- compute and report all problems.
--
-- Thus, errors and warnings are implemented as messages stored in raw data.
-- This module provides two predefined handlers: `error` and `warning`. They
-- are both functions that put the given message in the data.

-- Usage
-- -----
--
--
--
--       local tags    = require "cosy.lang.tags"
--       local message = require "cosy.lang.message"
--       local data = ...
--       message.error   (data, "My error message")
--       local errors   = data [tags.ERRORS]
--       message.warning (data, "My warning message")
--       local warnings = data [tags.WARNINGS]


-- Implementation details
-- ----------------------
--
-- This module makes use of `tags` for its two predefined handlers, and of
-- the `raw` function to access a raw data.
--
local tags = require "cosy.lang.tags"
local data = require "cosy.lang.data"
local raw = data.raw

-- The `custom` function takes a tag as parameter. It generates a message
-- handler that stores its messages under the given tag. Messages as stored
-- as a sequence, with insertion order preserved.
--
local function custom (tag)
  return function (data, message)
    data = raw (data)
    if not data [tag] then
      data [tag] = {}
    end
    local messages = data [tag]
    messages [#messages + 1] = message
  end
end

-- Usage
-- -----
--
-- The `custom` function is used as below: first, create a new handler by
-- passing a tag to `custom` and then use this handler by passing it a data
-- and a message. The stored messages are retrieved by accessing the custom
-- tag on the data.
--
--       local tags    = require "cosy.lang.tags"
--       local message = require "cosy.lang.message"
--       local handler = message.custom (tags.MY_TAG)
--       local data = ...
--       handler (data, "My message")
--       local messages = data [tags.MY_TAG]

-- Module
-- ------
--
-- This module exports the `custom` function to create new message handlers.
-- It also exports the two predefined handlers for errors and warnings.
--
return {
  custom  = custom,
  error   = custom (tags.ERRORS),
  warning = custom (tags.WARNINGS),
}
