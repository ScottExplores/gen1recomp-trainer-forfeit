local checks, failures = 0, 0

local function check(value, message)
  checks = checks + 1
  if not value then
    failures = failures + 1
    io.stderr:write("FAIL: " .. message .. "\n")
  end
end

local function equal(actual, expected, message)
  check(actual == expected, message .. " (expected " .. tostring(expected)
    .. ", got " .. tostring(actual) .. ")")
end

package.preload["src.core.Strings"] = function()
  return setmetatable({}, { __call = function(_, source, ...)
    return string.format(source, ...)
  end })
end

local buckets = { current = {} }
local current = "current"
local optionValues = {}
local schema = {
  { key = "rematches", default = true },
  { key = "adaptive_dialogue", default = true },
  { key = "trainer_growth", default = "gentle" },
}
local mod = {
  save = {
    get = function(_, key) return buckets[current][key] end,
    set = function(_, key, value) buckets[current][key] = value end,
  },
  options = {
    define = function(_, rows) schema = rows end,
    get = function(_, key)
      if optionValues[key] ~= nil then return optionValues[key] end
      for _, row in ipairs(schema or {}) do
        if row.key == key then return row.default end
      end
    end,
  },
}

local install = assert(loadfile("dialogue.lua"))()
local api = install(mod)
equal(api.installed, true, "dialogue installer reports active")
equal(api.format, 1, "memory format is versioned")
equal(#schema, 3, "dialogue leaves main's complete option schema intact")
equal(schema[3].key, "trainer_growth", "dialogue cannot drop growth setting")

local function game()
  return {
    save = {
      inventory = {}, money = 1000,
      party = {
        { species = "PIKACHU", level = 12, hp = 30 },
        { species = "BULBASAUR", level = 8, hp = 25 },
      },
    },
    data = {
      constants = { badges = {
        { id = "BOULDERBADGE" }, { id = "CASCADEBADGE" },
        { id = "THUNDERBADGE" },
      } },
      pokemon = {
        PIKACHU = { name = "PIKACHU" },
        BULBASAUR = { name = "BULBASAUR" },
      },
      trainers = {
        OPP_YOUNGSTER = { name = "YOUNGSTER" },
        OPP_LASS = { name = "LASS" },
        OPP_BUG_CATCHER = { name = "BUG CATCHER" },
      },
    },
    overworld = { map = { id = "ROUTE_3" } },
  }
end

local g = game()
local a = { id = "ROUTE_3_obj_1", cellX = 10, cellY = 10 }
local b = { id = "ROUTE_3_obj_2", cellX = 15, cellY = 12 }
local far = { id = "ROUTE_3_obj_3", cellX = 40, cellY = 40 }

equal(api:trainerKey(g, a, "OPP_YOUNGSTER", 1), "ROUTE_3_obj_1",
  "stable NPC id is the persistence key")
local first = api:context(g, a, "OPP_YOUNGSTER", 1)
equal(first.rematches, 0, "unseen trainer has no rematches")
equal(first.badges, 0, "badge count starts at zero")
equal(first.partyAverage, 10, "party average is rounded deterministically")
equal(first.strongestSpecies, "PIKACHU", "strongest party species is observed")
equal(first.recentNearbyWin, nil, "no nearby victory is invented")
check(first.text:find("PIKACHU", 1, true) ~= nil,
  "first adaptive line can reference the strongest party member")

local originalRandom = math.random
math.random = function() error("dialogue called RNG") end
local repeatA = api:context(g, a, "OPP_YOUNGSTER", 1).text
local repeatB = api:context(g, a, "OPP_YOUNGSTER", 1).text
math.random = originalRandom
equal(repeatA, repeatB, "identical context always selects identical text")

local recordedA = api:recordBattle(g, a, "OPP_YOUNGSTER", 1, "win",
  { isRematch = false })
equal(recordedA.wins, 1, "ordinary victory is remembered")
equal(recordedA.rematches, 0, "ordinary victory is not a rematch")
check(type(buckets.current.memory) == "table", "memory persists through mod.save")
equal(buckets.current.memory.sequence, 1, "battle sequence advances once")
equal(#buckets.current.memory.recentWins.ROUTE_3, 1,
  "real win enters bounded map history")

api:recordBattle(g, b, "OPP_LASS", 1, "win", { isRematch = false })
local afterNearby = api:context(g, a, "OPP_YOUNGSTER", 1)
check(type(afterNearby.recentNearbyWin) == "table",
  "tracked nearby trainer win is exposed")
equal(afterNearby.recentNearbyWin.trainerKey, "ROUTE_3_obj_2",
  "nearby context names the other trainer, never itself")
check(afterNearby.text:find("LASS", 1, true) ~= nil,
  "nearby line resolves the defeated trainer class name")
check(afterNearby.text:find("trained", 1, true) ~= nil,
  "nearby line still says the rematch trainer has trained")

api:recordBattle(g, far, "OPP_BUG_CATCHER", 1, "win", { isRematch = false })
local farContext = api:context(g, { id = "ROUTE_3_obj_4", cellX = 45, cellY = 45 },
  "OPP_LASS", 2)
check(type(farContext.recentNearbyWin) == "table"
  and farContext.recentNearbyWin.trainerKey == far.id,
  "distance check accepts only an actually tracked nearby win")
local noNear = api:context(g, { id = "ROUTE_3_obj_5", cellX = 80, cellY = 80 },
  "OPP_LASS", 3)
equal(noNear.recentNearbyWin, nil, "far victories are never described as nearby")

local rematch = api:recordBattle(g, a, "OPP_YOUNGSTER", 1, "run",
  { isRematch = true, paidForfeit = true })
equal(rematch.rematches, 1, "completed rematch count persists")
equal(rematch.forfeits, 1, "paid rematch forfeit persists")
equal(rematch.lastResult, "forfeit", "paid run has an explicit outcome")
check(api:context(g, a, "OPP_YOUNGSTER", 1).text
  :find("backing out", 1, true) ~= nil,
  "latest forfeit gets a relevant deterministic response")

g.save.inventory.BOULDERBADGE = 1
g.save.inventory.CASCADEBADGE = 1
local badgeLine = api:context(g, a, "OPP_YOUNGSTER", 1)
equal(badgeLine.badges, 2, "current badges are read from canonical inventory")
check(badgeLine.text:find("BADGES", 1, true) ~= nil,
  "badge progress can drive the line")

optionValues.adaptive_dialogue = false
local plain = api:context(g, a, "OPP_YOUNGSTER", 1)
equal(plain.adaptive, false, "dialogue option is honored")
equal(plain.text, "I've been training\nsince our last battle!",
  "disabled adaptation uses one safe authored fallback")
optionValues.adaptive_dialogue = nil

local partyDef = {
  { species = "RATTATA", level = 9, moves = { "TACKLE" } },
  { species = "EKANS", level = 99 },
}
local descriptor = api:rematchBoost(g, a, "OPP_YOUNGSTER", 1, partyDef)
equal(partyDef[1].level, 9, "source roster level is never mutated")
equal(partyDef[2].level, 99, "source cap-adjacent level is never mutated")
equal(descriptor.rematchNumber, 2, "descriptor numbers the next rematch")
equal(descriptor.boost, 4, "completed rematches produce a bounded boost")
equal(descriptor.levels[1], 13, "descriptor requests bounded growth")
equal(descriptor.levels[2], 100, "descriptor respects level 100 cap")
equal(partyDef[1].moves[1], "TACKLE", "descriptor leaves nested move data alone")
optionValues.rematches = false
local offDesc = api:rematchBoost(g, a, "OPP_YOUNGSTER", 1, partyDef)
equal(offDesc.boost, 0, "rematch option disables level boost")
equal(offDesc.levels[1], 9, "disabled boost describes the original level")
optionValues.rematches = nil

-- mod.save changes backing whenever the engine adopts another save.  The API
-- must re-read it on every call instead of leaking the previous slot's cache.
buckets.second = {}
current = "second"
local second = api:context(g, a, "OPP_YOUNGSTER", 1)
equal(second.rematches, 0, "switching saves does not leak trainer memory")
check(type(buckets.second.memory) == "table", "new save gets its own memory")
current = "current"
equal(api:context(g, a, "OPP_YOUNGSTER", 1).rematches, 1,
  "returning to original save restores its memory")

-- Context snapshots are detached: callers cannot corrupt persisted records.
local detached = api:context(g, a, "OPP_YOUNGSTER", 1)
detached.rematches = 999
if detached.recentNearbyWin then detached.recentNearbyWin.sequence = -10 end
equal(api:context(g, a, "OPP_YOUNGSTER", 1).rematches, 1,
  "mutating context cannot mutate persistence")

api:cleanup()
equal(api.installed, false, "cleanup retires dialogue API")
api:cleanup()
equal(api.installed, false, "cleanup is idempotent")

if failures > 0 then
  error(("%d/%d dialogue checks failed"):format(failures, checks), 0)
end
print(("Trainer dialogue: %d checks passed"):format(checks))
