local checks, failures = 0, 0
local function check(value, message)
  checks = checks + 1
  if not value then failures = failures + 1; io.stderr:write("FAIL: " .. message .. "\n") end
end
local function equal(actual, expected, message)
  check(actual == expected, message .. " (expected " .. tostring(expected)
    .. ", got " .. tostring(actual) .. ")")
end

local listeners, hooks = {}, {}
local function on(_, name, callback)
  listeners[name] = listeners[name] or {}
  local list = listeners[name]; list[#list + 1] = callback
  return function() for i, value in ipairs(list) do if value == callback then table.remove(list, i) break end end end
end
local function emit(name, payload)
  local copy = {}; for i, callback in ipairs(listeners[name] or {}) do copy[i] = callback end
  for _, callback in ipairs(copy) do callback(payload) end
end
local function wrap(_, name, callback)
  hooks[name] = callback
  return function() if hooks[name] == callback then hooks[name] = nil end end
end

local textBoxes, pushedBattles = {}, {}
local TextBox = {}
function TextBox.new(game, text, onDone, opts)
  local box = { game = game, text = text, onDone = onDone, opts = opts }
  return box
end

local headers = {
  [1] = { battle = "BATTLE1", won = "WON1", after = "AFTER1", range = 3 },
  [2] = { battle = "BOSS", won = "BOSS_WON", after = "BOSS_AFTER", range = 0 },
  [3] = { battle = "SCRIPT", won = "SCRIPT_WON", after = "SCRIPT_AFTER", range = 0 },
}
local Game = {
  save = { money = 500, party = { { hp = 10 } }, defeatedTrainers = {}, flags = {} },
  data = {
    text = { AFTER1 = "I learned a lot!", BOSS_AFTER = "Boss advice",
             SCRIPT_AFTER = "Story aftermath" },
    trainerHeader = function(_, _, index) return headers[index] end,
  },
  stack = { push = function(_, state) textBoxes[#textBoxes + 1] = state end },
}
local scripted = { TEXT_SCRIPTED = true }
local mapScripts = { talkScript = function(_, text) return scripted[text] end }
local victories = { ["OPP_BROCK#1"] = { badge = "BOULDERBADGE" } }

local Overworld = {}
function Overworld.talkTo(self, npc)
  self.vanillaTalks = (self.vanillaTalks or 0) + 1
  npc.frozen = true
end
local rawTalkTo = Overworld.talkTo
function Overworld.restoreBattleContinuation(self, battle, origin)
  self.vanillaRestores = (self.vanillaRestores or 0) + 1
  battle.onFinish = function()
    self.storyRewardReplays = (self.storyRewardReplays or 0) + 1
  end
  return "vanilla"
end
local rawRestoreBattleContinuation = Overworld.restoreBattleContinuation

local BattleState = {}
local sharedPartyDef = { { species = "RATTATA", level = 10,
  moves = { "TACKLE" } } }
function BattleState.newTrainer(game, class, party)
  local partyDef = sharedPartyDef
  if hooks["trainer.party"] then
    partyDef = hooks["trainer.party"](function(_, _, value) return value end,
      class, party or 1, partyDef)
  end
  local battle = {
    game = game, kind = "trainer", oppClass = class, partyIndex = party or 1,
    builtParty = partyDef, queue = {},
  }
  function battle:tryRun() return "vanilla" end
  function battle:sayChoice(text, callback) self.queue[#self.queue + 1] = { text = text, callback = callback } end
  function battle:say(text) self.queue[#self.queue + 1] = { text = text } end
  return battle
end

package.preload["src.core.Game"] = function() return Game end
package.preload["src.world.OverworldController"] = function() return Overworld end
package.preload["data.scripts.init"] = function() return mapScripts end
package.preload["data.scripts.victories"] = function() return victories end
package.preload["src.render.TextBox"] = function() return TextBox end
package.preload["src.battle.BattleState"] = function() return BattleState end

local dialogueCalls = { context = 0, before = 0, record = 0, boost = 0 }
local dialogueMode = { boost = "levels" }
local dialogueSource = [[return function(mod)
  local api = {}
  function api:context(game, npc, class, party)
    DIALOGUE_CALLS.context = DIALOGUE_CALLS.context + 1
    return { text = "I saw you beat a trainer nearby!" }
  end
  function api:beforeRematch(game, npc, class, party)
    DIALOGUE_CALLS.before = DIALOGUE_CALLS.before + 1
  end
  function api:recordBattle(game, npc, class, party, result, extra)
    DIALOGUE_CALLS.record = DIALOGUE_CALLS.record + 1
    DIALOGUE_CALLS.last = { result = result, extra = extra }
  end
  function api:rematchBoost(game, npc, class, party, partyDef)
    DIALOGUE_CALLS.boost = DIALOGUE_CALLS.boost + 1
    if DIALOGUE_MODE.boost == "lower" then
      return { levels = { [1] = 2 }, reason = "lower test", rematches = 1 }
    elseif DIALOGUE_MODE.boost == "bonus" then
      return { levelBonus = 500, reason = "bonus compatibility", rematches = 2 }
    end
    return { levels = { [1] = 12 }, reason = "trained", rematches = 1 }
  end
  return api
end]]
_G.DIALOGUE_CALLS = dialogueCalls
_G.DIALOGUE_MODE = dialogueMode

local optionValues = {
  rematches = true, adaptive_dialogue = true, trainer_growth = "gentle",
}
local optionSchema

local mod = {
  id = "trainer_forfeit", path = "mods/trainer_forfeit", exports = {},
  events = { on = on }, hooks = { wrap = wrap },
  read = function(_, relative) if relative == "dialogue.lua" then return dialogueSource end end,
  log = { warn = function() end },
  options = {
    define = function(_, schema) optionSchema = schema end,
    get = function(_, key) return optionValues[key] end,
  },
}

local ow = {
  map = { id = "ROUTE_3", def = { label = "Route3" } },
  player = { cellX = 5, cellY = 5 }, vanillaTalks = 0,
}
function ow:trainerDefeated(npc) return Game.save.defeatedTrainers[npc.id] == true end
function ow:afterBattle(result, battle) self.afterResult, self.afterBattleValue = result, battle end
function ow:pushBattle(battle)
  pushedBattles[#pushedBattles + 1] = battle
  emit("battle.started", { battle = battle, kind = "trainer" })
end
Game.overworld = ow
Game.stack.push = function(_, state) textBoxes[#textBoxes + 1] = state end

local function npc(id, index, class, text)
  local n = { id = id, def = { index = index, trainerClass = class,
    trainerParty = 1, text = text or "TEXT_GENERIC" }, facing = "up", frozen = false }
  function n:facePlayer() self.faced = true end
  return n
end

local install = assert(loadfile("main.lua"))()
local feature = install(mod)
equal(feature.installed, true, "installer publishes active status")
equal(feature.version, "0.2.1", "feature reports v0.2.1")
equal(feature.cost, 200, "fee is fixed at Y200")
equal(feature.rematches, true, "rematch adapter is active")
equal(feature.dialogue, true, "dialogue helper is active")
check(Overworld.talkTo ~= rawTalkTo, "talkTo receives guarded wrapper")
check(Overworld.restoreBattleContinuation ~= rawRestoreBattleContinuation,
  "checkpoint continuation receives guarded wrapper")
equal(#optionSchema, 3, "three focused options are registered")
equal(optionSchema[1].key, "rematches", "rematches option is registered")
equal(optionSchema[1].default, true, "rematches default is on")
equal(optionSchema[2].key, "adaptive_dialogue", "dialogue option is registered")
equal(optionSchema[2].default, true, "adaptive dialogue default is on")
equal(optionSchema[3].key, "trainer_growth", "growth option is registered")
equal(optionSchema[3].default, "gentle", "gentle growth is the default")
equal(optionSchema[3].choices[1][2], "off", "growth exposes OFF")
equal(optionSchema[3].choices[2][2], "gentle", "growth exposes GENTLE")

local ordinary = npc("ROUTE_3_obj_1", 1, "OPP_YOUNGSTER")
ow.npcPool = { [ordinary.id] = ordinary }
Game.save.defeatedTrainers[ordinary.id] = true
Overworld.talkTo(ow, ordinary)
equal(ow.vanillaTalks, 0, "defeated ordinary trainer bypasses vanilla after-text")
equal(ordinary.frozen, true, "trainer freezes during rematch prompt")
equal(ordinary.faced, true, "trainer faces player")
local prompt = textBoxes[#textBoxes]
check(prompt.text:find("I learned a lot!", 1, true) ~= nil,
  "vanilla post-battle text is preserved")
check(prompt.text:find("nearby", 1, true) ~= nil, "journey context appears in prompt")
check(prompt.text:find("Want a rematch?", 1, true) ~= nil, "prompt asks for rematch")
check(type(prompt.opts.choice) == "function", "prompt owns yes/no callback")

prompt.opts.choice(false)
equal(ordinary.frozen, false, "NO unfreezes trainer")
equal(#pushedBattles, 0, "NO starts no battle")

ordinary.frozen = false
Overworld.talkTo(ow, ordinary)
textBoxes[#textBoxes].opts.choice(true)
local rematch = pushedBattles[#pushedBattles]
check(rematch ~= nil and rematch.trainerForfeitRematch == true, "YES starts tagged rematch")
equal(rematch.builtParty[1].level, 12, "rematch-only trainer.party boost applies")
equal(sharedPartyDef[1].level, 10, "rematch growth never mutates shared roster data")
check(rematch.builtParty ~= sharedPartyDef, "rematch receives an isolated party definition")
equal(rematch.builtParty[1].moves[1], "TACKLE", "nested party data survives cloning")
check(rematch.builtParty[1].moves ~= sharedPartyDef[1].moves,
  "nested party data is independently cloned")
equal(rematch.checkpointOrigin.kind, "trainer_encounter",
  "checkpoint uses the engine's recognized trainer kind")
equal(rematch.checkpointOrigin.trainerForfeitRematch, true,
  "checkpoint carries the reward-safe rematch marker")
equal(rematch.checkpointOrigin.npcId, ordinary.id,
  "checkpoint identifies the defeated NPC")
equal(dialogueCalls.before, 1, "dialogue records rematch preparation")
equal(dialogueCalls.boost, 1, "dialogue supplies rematch scaling")
check(rematch.tryRun ~= nil, "rematch RUN receives forfeit wrapper")
rematch:tryRun()
check(rematch.queue[1].text:find("¥200", 1, true) ~= nil,
  "forfeit prompt shows the exact ¥200 fee")
rematch.queue[1].callback(true)
equal(Game.save.money, 300, "rematch forfeit costs exactly Y200")
equal(rematch.result, "run", "rematch forfeit exits neutrally")
rematch.onFinish("run")
equal(ow.afterResult, "run", "rematch continuation calls overworld afterBattle")
equal(ordinary.frozen, false, "rematch completion unfreezes trainer")
equal(Game.save.defeatedTrainers[ordinary.id], true, "rematch never clears defeated marker")
equal(dialogueCalls.last.extra.isRematch, true, "journey record identifies rematch")
equal(dialogueCalls.last.extra.paidForfeit, true, "journey record identifies paid forfeit")

-- Growth descriptors are bounded, non-lowering, and optional at runtime.
dialogueMode.boost = "lower"
Overworld.talkTo(ow, ordinary); textBoxes[#textBoxes].opts.choice(true)
local lowerAttempt = pushedBattles[#pushedBattles]
equal(lowerAttempt.builtParty[1].level, 10, "growth never lowers a roster level")
lowerAttempt.onFinish("win")

optionValues.trainer_growth = "off"
local boostsBeforeOff = dialogueCalls.boost
dialogueMode.boost = "bonus"
Overworld.talkTo(ow, ordinary); textBoxes[#textBoxes].opts.choice(true)
local growthOff = pushedBattles[#pushedBattles]
equal(growthOff.builtParty[1].level, 10, "OFF disables rematch growth")
equal(dialogueCalls.boost, boostsBeforeOff, "OFF skips the growth provider")
growthOff.onFinish("win")

optionValues.trainer_growth = "gentle"
Overworld.talkTo(ow, ordinary); textBoxes[#textBoxes].opts.choice(true)
local bonusGrowth = pushedBattles[#pushedBattles]
equal(bonusGrowth.builtParty[1].level, 100,
  "numeric levelBonus compatibility is clamped to level 100")
bonusGrowth.onFinish("win")
dialogueMode.boost = "levels"

-- Disabling adaptive text preserves the original post-battle line.
optionValues.adaptive_dialogue = false
local contextsBeforeOff = dialogueCalls.context
Overworld.talkTo(ow, ordinary)
local nonAdaptivePrompt = textBoxes[#textBoxes]
equal(dialogueCalls.context, contextsBeforeOff, "adaptive dialogue OFF skips context")
check(nonAdaptivePrompt.text:find("I learned a lot!", 1, true) ~= nil,
  "non-adaptive prompt keeps the vanilla post-text")
check(nonAdaptivePrompt.text:find("nearby", 1, true) == nil,
  "non-adaptive prompt omits journey context")
nonAdaptivePrompt.opts.choice(false)
optionValues.adaptive_dialogue = true

optionValues.rematches = false
Overworld.talkTo(ow, ordinary)
equal(ow.vanillaTalks, 1, "rematches OFF delegates to vanilla talk")
optionValues.rematches = true

-- A resumed 0.1.80 rematch gets a reward-free continuation and paid RUN.
local restored = BattleState.newTrainer(Game, "OPP_YOUNGSTER", 1)
local restoredRawRun = restored.tryRun
local restoredOrigin = {
  kind = "trainer_encounter", map = ow.map.id, npcId = ordinary.id,
  trainerClass = "OPP_YOUNGSTER", partyIndex = 1,
  trainerForfeitRematch = true,
}
equal(Overworld.restoreBattleContinuation(ow, restored, restoredOrigin), true,
  "marked rematch checkpoint restores safely")
equal(ow.vanillaRestores or 0, 0,
  "marked rematch never reaches the reward-bearing continuation")
check(restored.tryRun ~= restoredRawRun, "restored rematch retains paid RUN")
restored.onFinish("win")
equal(ow.storyRewardReplays or 0, 0,
  "restored rematch cannot replay a story reward")
equal(Game.save.defeatedTrainers[ordinary.id], true,
  "restored rematch preserves the defeated marker")

local unrelatedRestore = BattleState.newTrainer(Game, "OPP_YOUNGSTER", 1)
equal(Overworld.restoreBattleContinuation(ow, unrelatedRestore, {
  kind = "trainer_encounter", map = ow.map.id, npcId = ordinary.id,
  trainerClass = "OPP_YOUNGSTER", partyIndex = 1,
}), "vanilla", "unmarked checkpoints delegate to the engine")
equal(ow.vanillaRestores, 1, "only unmarked checkpoint reached engine restore")

-- A normal trainer construction is never scaled without the short-lived tag.
local normalBuild = BattleState.newTrainer(Game, "OPP_YOUNGSTER", 1)
equal(normalBuild.builtParty[1].level, 10, "trainer.party boost cannot leak")

-- Undefeated ordinary trainers and all special/script-owned trainers delegate.
local unbeaten = npc("ROUTE_3_obj_2", 1, "OPP_YOUNGSTER")
Overworld.talkTo(ow, unbeaten)
equal(ow.vanillaTalks, 2, "undefeated trainer keeps vanilla engagement")

local boss = npc("PEWTER_GYM_obj_1", 2, "OPP_BROCK")
Game.save.defeatedTrainers[boss.id] = true
Overworld.talkTo(ow, boss)
equal(ow.vanillaTalks, 3, "victory/reward trainer is excluded")

local rival = npc("ROUTE_22_obj_1", 1, "OPP_RIVAL1")
Game.save.defeatedTrainers[rival.id] = true
Overworld.talkTo(ow, rival)
equal(ow.vanillaTalks, 4, "rival is excluded")

local scriptedNpc = npc("ROCKET_HIDEOUT_B4F_obj_3", 3, "OPP_ROCKET", "TEXT_SCRIPTED")
Game.save.defeatedTrainers[scriptedNpc.id] = true
Overworld.talkTo(ow, scriptedNpc)
equal(ow.vanillaTalks, 5, "map-script trainer is excluded")

-- Story-owned engageTrainer emissions cannot arm forfeiting anymore.
emit("world.trainer_engaged", { npc = boss, trainerClass = boss.def.trainerClass, partyIndex = 1 })
local bossBattle = BattleState.newTrainer(Game, "OPP_BROCK", 1)
local bossRun = bossBattle.tryRun
emit("battle.started", { battle = bossBattle, kind = "trainer" })
equal(bossBattle.tryRun, bossRun, "leader forfeit is excluded")

emit("world.trainer_engaged", { npc = scriptedNpc, trainerClass = "OPP_ROCKET", partyIndex = 1 })
local storyBattle = BattleState.newTrainer(Game, "OPP_ROCKET", 1)
local storyRun = storyBattle.tryRun
emit("battle.started", { battle = storyBattle, kind = "trainer" })
equal(storyBattle.tryRun, storyRun, "map-script forfeit is excluded")

-- Undefeated generic engagement still receives the paid RUN flow.
emit("world.trainer_engaged", { npc = unbeaten, trainerClass = "OPP_YOUNGSTER", partyIndex = 1 })
local regularBattle = BattleState.newTrainer(Game, "OPP_YOUNGSTER", 1)
local regularRun = regularBattle.tryRun
emit("battle.started", { battle = regularBattle, kind = "trainer" })
check(regularBattle.tryRun ~= regularRun, "ordinary first battle gets forfeit")
regularBattle:tryRun(); regularBattle.queue[1].callback(false)
equal(Game.save.money, 300, "declined forfeit remains free")
emit("battle.ended", { battle = regularBattle, result = "win" })
equal(regularBattle.tryRun, regularRun, "battle end restores original RUN")
equal(dialogueCalls.last.extra.isRematch, false, "ordinary result is recorded")

feature.cleanup()
equal(feature.installed, false, "cleanup retires feature")
equal(Overworld.talkTo, rawTalkTo, "cleanup restores talkTo")
equal(Overworld.restoreBattleContinuation, rawRestoreBattleContinuation,
  "cleanup restores checkpoint continuation")
equal(hooks["trainer.party"], nil, "cleanup removes trainer.party hook")
equal(#(listeners["battle.started"] or {}), 0, "cleanup removes listeners")

if failures > 0 then error(("%d/%d trainer-forfeit checks failed"):format(failures, checks), 0) end
print(("Trainer Forfeit & Rematches: %d checks passed"):format(checks))
