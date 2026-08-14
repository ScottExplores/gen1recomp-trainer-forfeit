-- Run from a Gen1Recomp checkout:
--   luajit <mod>/tests/full_load.lua <directory-containing-trainer_forfeit>

local argv = rawget(_G, "arg") or {}
local fixtureRoot = argv[2] or os.getenv("TRAINER_FORFEIT_FIXTURE_ROOT") or "."
local engineRoot = os.getenv("TRAINER_FORFEIT_ENGINE_ROOT") or fixtureRoot
package.path = engineRoot .. "/?.lua;" .. engineRoot .. "/?/init.lua;"
  .. fixtureRoot .. "/?.lua;" .. fixtureRoot .. "/?/init.lua;"
  .. "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local parent = argv[1] or os.getenv("TRAINER_FORFEIT_MOD_PARENT")
assert(parent, "pass directory containing trainer_forfeit")
local T = require("tests.modkit")

-- Use the SDK's in-memory filesystem so this smoke is independent of whether
-- a host Lua build allows io.open() on Windows directories.
local function read(relative)
  local path = parent .. "/trainer_forfeit/" .. relative
  local handle = assert(io.open(path, "rb"), "cannot read " .. path)
  local body = handle:read("*a")
  handle:close()
  return body
end
local fs = T.sdk.memfs({
  ["mods/trainer_forfeit/manifest.json"] = read("manifest.json"),
  ["mods/trainer_forfeit/main.lua"] = read("main.lua"),
  ["mods/trainer_forfeit/dialogue.lua"] = read("dialogue.lua"),
})

local run = T.sdk.loadMod("mods/trainer_forfeit", {
  data = require("tests.modkit.fixtures").fresh(),
  fs = fs,
  generation = 1,
})

T.eq(#run.errors, 0, "Trainer Forfeit & Rematches loads through API-2 loader")
T.check(run.mod ~= nil, "loader selected Trainer Forfeit & Rematches")
T.eq(run.mod and run.mod.manifest and run.mod.manifest.version, "0.3.0",
  "loader selected the v0.3.0 release")
local status = run.loader.exports.trainer_forfeit
  and run.loader.exports.trainer_forfeit.status
T.check(type(status) == "table" and status.installed == true,
  "feature status is published")
T.eq(status and status.cost, 200, "published fee is fixed at ¥200")
T.eq(status and status.version, "0.3.0", "published feature version matches manifest")
T.eq(status and status.rematches, true, "rematch adapter is active")
T.eq(status and status.gymLeaders, true, "Gym Leader rematches are active")
T.eq(status and status.dialogue, true, "offline dialogue helper is active")
T.eq(status and status.optionDefaults and status.optionDefaults.rematches, true,
  "rematches default to enabled")
T.eq(status and status.optionDefaults and status.optionDefaults.adaptive_dialogue,
  true, "adaptive dialogue defaults to enabled")
T.eq(status and status.optionDefaults and status.optionDefaults.trainer_growth,
  "gentle", "trainer growth defaults to gentle")

local schema = run.loader.optionSchemas
  and run.loader.optionSchemas.trainer_forfeit or {}
local options = {}
for _, row in ipairs(schema) do options[row.key] = row end
T.eq(options.rematches and options.rematches.default, true,
  "runtime schema exposes rematches")
T.eq(options.adaptive_dialogue and options.adaptive_dialogue.default, true,
  "runtime schema exposes adaptive dialogue")
T.eq(options.trainer_growth and options.trainer_growth.default, "gentle",
  "runtime schema exposes gentle trainer growth")

if status and status.cleanup then status.cleanup() end
T.eq(status and status.installed, false, "feature cleanup retires installation")
run.release()
T.finish("trainer_forfeit full load")
