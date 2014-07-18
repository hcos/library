-- Ignoring parameters
-- ===================
--
-- Coding standards in CosyVerif require:
--
-- * 100 % code coverage by tests;
-- * no warning by luacheck.
--
-- The latter is difficult to reach as warnings are emitted for unused
-- function parameters. To explicitly state that these parameters are
-- useless, please use the `ignore` function.
--
-- ### Usage
--
--      function f (a, b, c)
--        ignore (a, c)
--        ...
--      end
--
-- ### Warning
--
-- Using the `ignore` function is __not__ efficient in the standard Lua
-- interpreter. It is almost as good as not using it in LuaJIT (see
-- the benchmarks in `util.bench.lua`).
--
-- In all cases, prefer it to the usual construct `local _ = a, b`, as the
-- intention in the latter is not obvious for non Lua programmers.
--
-- ### Implementation
--
-- Implementation is trivial: we use variadic arguments and do nothing of
-- them.
--
local function ignore (...)
end

return ignore
