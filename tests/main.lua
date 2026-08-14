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

-- These fixtures deliberately mirror the engine's exact Gen I object names,
-- text constants, battle parties, badges, and completion flags.  A typo in
-- any whitelist field must fail closed and leave the map-owned script alone.
local gymLeaders = {
  {
    id = "PEWTER_GYM_obj_1", map = "PEWTER_GYM", label = "PewterGym",
    name = "PEWTERGYM_BROCK", text = "TEXT_PEWTERGYM_BROCK",
    class = "OPP_BROCK", party = 1, badge = "BOULDERBADGE",
    flag = "EVENT_BEAT_BROCK", gotFlag = "EVENT_GOT_TM34", item = "TM_BIDE",
    after = "_PewterGymBrockPostBattleAdviceText", post = "Brock rematch advice",
  },
  {
    id = "CERULEAN_GYM_obj_1", map = "CERULEAN_GYM", label = "CeruleanGym",
    name = "CERULEANGYM_MISTY", text = "TEXT_CERULEANGYM_MISTY",
    class = "OPP_MISTY", party = 1, badge = "CASCADEBADGE",
    flag = "EVENT_BEAT_MISTY", gotFlag = "EVENT_GOT_TM11", item = "TM_BUBBLEBEAM",
    after = "_CeruleanGymMistyTM11ExplanationText", post = "Misty rematch advice",
  },
  {
    id = "VERMILION_GYM_obj_1", map = "VERMILION_GYM", label = "VermilionGym",
    name = "VERMILIONGYM_LT_SURGE", text = "TEXT_VERMILIONGYM_LT_SURGE",
    class = "OPP_LT_SURGE", party = 1, badge = "THUNDERBADGE",
    flag = "EVENT_BEAT_LT_SURGE", gotFlag = "EVENT_GOT_TM24", item = "TM_THUNDERBOLT",
    after = "_VermilionGymLTSurgePostBattleAdviceText", post = "Surge rematch advice",
  },
  {
    id = "CELADON_GYM_obj_1", map = "CELADON_GYM", label = "CeladonGym",
    name = "CELADONGYM_ERIKA", text = "TEXT_CELADONGYM_ERIKA",
    class = "OPP_ERIKA", party = 1, badge = "RAINBOWBADGE",
    flag = "EVENT_BEAT_ERIKA", gotFlag = "EVENT_GOT_TM21", item = "TM_MEGA_DRAIN",
    after = "_CeladonGymErikaPostBattleAdviceText", post = "Erika rematch advice",
  },
  {
    id = "FUCHSIA_GYM_obj_1", map = "FUCHSIA_GYM", label = "FuchsiaGym",
    name = "FUCHSIAGYM_KOGA", text = "TEXT_FUCHSIAGYM_KOGA",
    class = "OPP_KOGA", party = 1, badge = "SOULBADGE",
    flag = "EVENT_BEAT_KOGA", gotFlag = "EVENT_GOT_TM06", item = "TM_TOXIC",
    after = "_FuchsiaGymKogaPostBattleAdviceText", post = "Koga rematch advice",
  },
  {
    id = "SAFFRON_GYM_obj_1", map = "SAFFRON_GYM", label = "SaffronGym",
    name = "SAFFRONGYM_SABRINA", text = "TEXT_SAFFRONGYM_SABRINA",
    class = "OPP_SABRINA", party = 1, badge = "MARSHBADGE",
    flag = "EVENT_BEAT_SABRINA", gotFlag = "EVENT_GOT_TM46", item = "TM_PSYWAVE",
    after = "_SaffronGymSabrinaPostBattleAdviceText", post = "Sabrina rematch advice",
  },
  {
    id = "CINNABAR_GYM_obj_1", map = "CINNABAR_GYM", label = "CinnabarGym",
    name = "CINNABARGYM_BLAINE", text = "TEXT_CINNABARGYM_BLAINE",
    class = "OPP_BLAINE", party = 1, badge = "VOLCANOBADGE",
    flag = "EVENT_BEAT_BLAINE", gotFlag = "EVENT_GOT_TM38", item = "TM_FIRE_BLAST",
    after = "_CinnabarGymBlainePostBattleAdviceText", post = "Blaine rematch advice",
  },
}

local giovanni = {
  leaderId = "VIRIDIAN_GYM_obj_1", guideId = "VIRIDIAN_GYM_obj_10",
  map = "VIRIDIAN_GYM", label = "ViridianGym",
  leaderName = "VIRIDIANGYM_GIOVANNI", leaderText = "TEXT_VIRIDIANGYM_GIOVANNI",
  guideName = "VIRIDIANGYM_GYM_GUIDE", guideText = "TEXT_VIRIDIANGYM_GYM_GUIDE",
  class = "OPP_GIOVANNI", party = 3, badge = "EARTHBADGE",
  flag = "EVENT_BEAT_GIOVANNI", gotFlag = "EVENT_GOT_TM27", item = "TM_FISSURE",
  after = "_ViridianGymGuidePostBattleText", post = "Giovanni rematch advice",
}

local Game = {
  save = {
    money = 500, party = { { hp = 10 } }, defeatedTrainers = {},
    flags = {}, inventory = {}, objectToggles = {},
  },
  data = {
    text = { AFTER1 = "I learned a lot!", BOSS_AFTER = "Boss advice",
             SCRIPT_AFTER = "Story aftermath" },
    trainerHeader = function(_, _, index) return headers[index] end,
  },
  stack = { push = function(_, state) textBoxes[#textBoxes + 1] = state end },
}
for _, leader in ipairs(gymLeaders) do
  Game.data.text[leader.after] = leader.post
end
Game.data.text[giovanni.after] = giovanni.post

local scripted = { TEXT_SCRIPTED = true }
for _, leader in ipairs(gymLeaders) do scripted[leader.text] = true end
scripted[giovanni.leaderText] = true
scripted[giovanni.guideText] = true
local mapScripts = { talkScript = function(_, text) return scripted[text] end }

local victories = {}
for _, leader in ipairs(gymLeaders) do
  victories[leader.class .. "#" .. leader.party] = {
    badge = leader.badge, flag = leader.flag,
    gotFlag = leader.gotFlag, item = leader.item,
  }
end
victories[giovanni.class .. "#" .. giovanni.party] = {
  badge = giovanni.badge, flag = giovanni.flag,
  gotFlag = giovanni.gotFlag, item = giovanni.item,
}
victories["OPP_GIOVANNI#2"] = { flag = "EVENT_BEAT_SILPH_CO_GIOVANNI" }
victories["OPP_BLACKBELT#1"] = { flag = "EVENT_BEAT_KARATE_MASTER" }
victories["OPP_LORELEI#1"] = {
  flag = "EVENT_BEAT_LORELEIS_ROOM_TRAINER_0",
}

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
    DIALOGUE_CALLS.lastContext = {
      npcId = npc and npc.id, class = class, party = party,
      npcName = npc and npc.def and npc.def.name,
      cellX = npc and npc.cellX, cellY = npc and npc.cellY,
    }
    return { text = "I saw you beat a trainer nearby!" }
  end
  function api:beforeRematch(game, npc, class, party)
    DIALOGUE_CALLS.before = DIALOGUE_CALLS.before + 1
    DIALOGUE_CALLS.lastBefore = {
      npcId = npc and npc.id, class = class, party = party,
      npcName = npc and npc.def and npc.def.name,
      cellX = npc and npc.cellX, cellY = npc and npc.cellY,
    }
  end
  function api:recordBattle(game, npc, class, party, result, extra)
    DIALOGUE_CALLS.record = DIALOGUE_CALLS.record + 1
    DIALOGUE_CALLS.last = { result = result, extra = extra }
  end
  function api:rematchBoost(game, npc, class, party, partyDef)
    DIALOGUE_CALLS.boost = DIALOGUE_CALLS.boost + 1
    DIALOGUE_CALLS.lastBoost = {
      npcId = npc and npc.id, class = class, party = party,
      npcName = npc and npc.def and npc.def.name,
      cellX = npc and npc.cellX, cellY = npc and npc.cellY,
    }
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

local function npc(id, index, class, text, name, party)
  local n = { id = id, def = { index = index, trainerClass = class,
    trainerParty = party or 1, text = text or "TEXT_GENERIC", name = name },
    facing = "up", frozen = false }
  function n:facePlayer() self.faced = true end
  return n
end

local function selectMap(id, label)
  ow.map = { id = id, def = { label = label or id } }
end

local function completeGym(target)
  Game.save.flags[target.flag] = true
  Game.save.flags[target.gotFlag] = true
  Game.save.inventory[target.badge] = 1
end

local function clearGym(target)
  Game.save.flags[target.flag] = nil
  Game.save.flags[target.gotFlag] = nil
  Game.save.inventory[target.badge] = nil
end

local function gymNpc(target)
  return npc(target.id, 1, target.class, target.text,
    target.name, target.party)
end

local install = assert(loadfile("main.lua"))()
local feature = install(mod)
equal(feature.installed, true, "installer publishes active status")
equal(feature.version, "0.3.0", "feature reports v0.3.0")
equal(feature.cost, 200, "fee is fixed at Y200")
equal(feature.rematches, true, "rematch adapter is active")
equal(feature.gymLeaders, true, "Gym Leader rematch adapter is active")
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

-- Undefeated ordinary trainers still delegate.
local unbeaten = npc("ROUTE_3_obj_2", 1, "OPP_YOUNGSTER")
selectMap("ROUTE_3", "Route3")
local talksBeforeUnbeaten = ow.vanillaTalks
Overworld.talkTo(ow, unbeaten)
equal(ow.vanillaTalks, talksBeforeUnbeaten + 1,
  "undefeated trainer keeps vanilla engagement")

-- Gym rematches are completion-gated.  A pre-win leader, an unrecorded
-- badge, or a pending TM handoff always retains the vanilla talk script.
local brockDef = gymLeaders[1]
local boss = gymNpc(brockDef)
selectMap(brockDef.map, brockDef.label)
ow.npcPool = { [boss.id] = boss }
clearGym(brockDef)
Game.save.defeatedTrainers[boss.id] = nil

local talksBeforePreWin = ow.vanillaTalks
Overworld.talkTo(ow, boss)
equal(ow.vanillaTalks, talksBeforePreWin + 1,
  "pre-win Gym Leader delegates to the map script")

Game.save.flags[brockDef.flag] = true
Game.save.flags[brockDef.gotFlag] = true
Game.save.inventory[brockDef.badge] = nil
local talksBeforeMissingBadge = ow.vanillaTalks
Overworld.talkTo(ow, boss)
equal(ow.vanillaTalks, talksBeforeMissingBadge + 1,
  "completed flags without the badge delegate safely")

Game.save.inventory[brockDef.badge] = 1
Game.save.flags[brockDef.gotFlag] = nil
Game.save.defeatedTrainers[boss.id] = true
local talksBeforePendingTM = ow.vanillaTalks
Overworld.talkTo(ow, boss)
equal(ow.vanillaTalks, talksBeforePendingTM + 1,
  "pending Gym Leader TM handoff delegates even with defeatedTrainers set")

-- Initial story-owned leader engagements never receive paid RUN.
emit("world.trainer_engaged", {
  npc = boss, trainerClass = boss.def.trainerClass, partyIndex = brockDef.party,
})
local bossBattle = BattleState.newTrainer(Game, brockDef.class, brockDef.party)
local bossRun = bossBattle.tryRun
emit("battle.started", { battle = bossBattle, kind = "trainer" })
equal(bossBattle.tryRun, bossRun,
  "initial Gym Leader battle cannot buy a forfeit")

-- Even a completed save fails closed if an exact whitelist field is wrong.
completeGym(brockDef)
boss.def.name = "PEWTERGYM_BROCK_TYPO"
local talksBeforeBadIdentity = ow.vanillaTalks
Overworld.talkTo(ow, boss)
equal(ow.vanillaTalks, talksBeforeBadIdentity + 1,
  "mismatched Gym Leader object identity delegates")
boss.def.name = brockDef.name

-- Imported completed saves need no defeatedTrainers entry.  Exercise all
-- seven persistent leaders and assert exact mappings and reward-free wins.
local leaderNpcs = {}
for _, target in ipairs(gymLeaders) do
  local leader = target == brockDef and boss or gymNpc(target)
  leaderNpcs[target.class] = leader
  selectMap(target.map, target.label)
  ow.npcPool = { [leader.id] = leader }
  clearGym(target)
  completeGym(target)
  Game.save.defeatedTrainers[leader.id] = nil
  Game.save.inventory[target.item] = 3
  Game.save.objectToggles[target.map] = { REMATCH_SENTINEL = true }

  local talksBefore = ow.vanillaTalks
  local rewardsBefore = ow.storyRewardReplays or 0
  Overworld.talkTo(ow, leader)
  equal(ow.vanillaTalks, talksBefore,
    target.class .. " completed imported save opens rematch")
  local leaderPrompt = textBoxes[#textBoxes]
  check(leaderPrompt.text:find(target.post, 1, true) ~= nil,
    target.class .. " uses exact post-battle text")
  check(leaderPrompt.text:find("Want a rematch?", 1, true) ~= nil,
    target.class .. " uses the normal leader challenge")
  leaderPrompt.opts.choice(true)

  local battle = pushedBattles[#pushedBattles]
  equal(battle.oppClass, target.class,
    target.class .. " launches exact trainer class")
  equal(battle.partyIndex, target.party,
    target.class .. " launches exact party")
  equal(battle.checkpointOrigin.map, target.map,
    target.class .. " checkpoint records exact Gym map")
  equal(battle.checkpointOrigin.npcId, target.id,
    target.class .. " checkpoint records exact NPC")
  equal(battle.checkpointOrigin.trainerForfeitIdentity, target.id,
    target.class .. " keeps its own memory identity")
  equal(dialogueCalls.lastContext.npcId, target.id,
    target.class .. " journey context uses leader identity")
  battle.onFinish("win")

  equal(ow.afterResult, "win", target.class .. " win uses safe continuation")
  equal(ow.afterBattleValue, battle,
    target.class .. " win returns the rematch battle to overworld")
  equal(ow.storyRewardReplays or 0, rewardsBefore,
    target.class .. " win never replays story rewards")
  equal(Game.save.flags[target.flag], true,
    target.class .. " win preserves victory flag")
  equal(Game.save.flags[target.gotFlag], true,
    target.class .. " win preserves TM completion flag")
  equal(Game.save.inventory[target.badge], 1,
    target.class .. " win does not duplicate/remove badge")
  equal(Game.save.inventory[target.item], 3,
    target.class .. " win does not duplicate/remove TM")
  equal(Game.save.objectToggles[target.map].REMATCH_SENTINEL, true,
    target.class .. " win leaves object toggles untouched")
  equal(Game.save.defeatedTrainers[leader.id], nil,
    target.class .. " imported save needs no synthetic defeated marker")
end

-- A paid forfeit in a leader rematch is also reward-safe and charged once.
local mistyDef = gymLeaders[2]
local misty = leaderNpcs[mistyDef.class]
selectMap(mistyDef.map, mistyDef.label)
ow.npcPool = { [misty.id] = misty }
Game.save.money = 1000
Overworld.talkTo(ow, misty)
textBoxes[#textBoxes].opts.choice(true)
local mistyForfeit = pushedBattles[#pushedBattles]
mistyForfeit:tryRun()
mistyForfeit.queue[1].callback(true)
equal(Game.save.money, 800, "Gym Leader rematch forfeit charges exactly Y200 once")
equal(mistyForfeit.result, "run", "Gym Leader paid forfeit exits neutrally")
mistyForfeit.onFinish("run")
equal(Game.save.flags[mistyDef.flag], true,
  "Gym Leader forfeit preserves victory flag")
equal(Game.save.flags[mistyDef.gotFlag], true,
  "Gym Leader forfeit preserves TM completion flag")
equal(Game.save.inventory[mistyDef.badge], 1,
  "Gym Leader forfeit preserves badge")
equal(Game.save.inventory[mistyDef.item], 3,
  "Gym Leader forfeit cannot duplicate TM")
equal(Game.save.objectToggles[mistyDef.map].REMATCH_SENTINEL, true,
  "Gym Leader forfeit leaves object toggles untouched")

-- Marked leader checkpoints restore only when every origin and live-save
-- identity check matches. Tampering fails closed without reward continuation.
local kogaDef = gymLeaders[5]
local koga = leaderNpcs[kogaDef.class]
selectMap(kogaDef.map, kogaDef.label)
ow.npcPool = { [koga.id] = koga }
local leaderRestore = BattleState.newTrainer(Game, kogaDef.class, kogaDef.party)
local leaderRestoreRawRun = leaderRestore.tryRun
local leaderOrigin = {
  kind = "trainer_encounter", map = kogaDef.map, npcId = kogaDef.id,
  trainerClass = kogaDef.class, partyIndex = kogaDef.party,
  trainerForfeitIdentity = kogaDef.id, trainerForfeitRematch = true,
}
local vanillaBeforeLeaderRestore = ow.vanillaRestores
equal(Overworld.restoreBattleContinuation(ow, leaderRestore, leaderOrigin), true,
  "completed Gym Leader checkpoint restores reward-free")
equal(ow.vanillaRestores, vanillaBeforeLeaderRestore,
  "Gym Leader restore bypasses reward-bearing engine continuation")
check(leaderRestore.tryRun ~= leaderRestoreRawRun,
  "restored Gym Leader rematch retains paid RUN")
leaderRestore.onFinish("win")
equal(ow.storyRewardReplays or 0, 0,
  "restored Gym Leader win cannot replay a story reward")

local function tamperedLeaderRestore(label, patchOrigin)
  local battle = BattleState.newTrainer(Game, kogaDef.class, kogaDef.party)
  local rawRun = battle.tryRun
  local origin = {
    kind = "trainer_encounter", map = kogaDef.map, npcId = kogaDef.id,
    trainerClass = kogaDef.class, partyIndex = kogaDef.party,
    trainerForfeitIdentity = kogaDef.id, trainerForfeitRematch = true,
  }
  if patchOrigin then patchOrigin(origin) end
  local vanillaBefore = ow.vanillaRestores
  equal(Overworld.restoreBattleContinuation(ow, battle, origin), false,
    label .. " checkpoint fails closed")
  equal(ow.vanillaRestores, vanillaBefore,
    label .. " never delegates to reward-bearing restore")
  equal(battle.tryRun, rawRun, label .. " never attaches paid RUN")
end

tamperedLeaderRestore("wrong-map Gym Leader", function(origin)
  origin.map = "FUCHSIA_CITY"
end)
tamperedLeaderRestore("wrong-class Gym Leader", function(origin)
  origin.trainerClass = "OPP_BROCK"
end)
tamperedLeaderRestore("wrong-party Gym Leader", function(origin)
  origin.partyIndex = 2
end)
tamperedLeaderRestore("wrong-NPC Gym Leader", function(origin)
  origin.npcId = "FUCHSIA_GYM_obj_2"
end)
tamperedLeaderRestore("wrong-identity Gym Leader", function(origin)
  origin.trainerForfeitIdentity = "FUCHSIA_GYM_obj_2"
end)
Game.save.flags[kogaDef.gotFlag] = nil
tamperedLeaderRestore("incomplete-live-save Gym Leader")
Game.save.flags[kogaDef.gotFlag] = true

-- Giovanni disappears after his required farewell. His direct object and a
-- guide while he is visible stay map-owned; only the exact hidden-state guide
-- launches Viridian party #3 with a synthetic Giovanni memory identity.
selectMap(giovanni.map, giovanni.label)
clearGym(giovanni)
completeGym(giovanni)
-- Cartridge-imported saves use the original event name instead of the
-- recomp-local victory-table name.  Either completed flag must work, while
-- the badge, TM flag, and hidden Giovanni state remain mandatory.
Game.save.flags[giovanni.flag] = nil
Game.save.flags.EVENT_BEAT_VIRIDIAN_GYM_GIOVANNI = true
local giovanniNpc = npc(giovanni.leaderId, 1, giovanni.class,
  giovanni.leaderText, giovanni.leaderName, giovanni.party)
local guide = npc(giovanni.guideId, 10, nil,
  giovanni.guideText, giovanni.guideName)
guide.cellX, guide.cellY = 4, 9
ow.npcPool = { [giovanniNpc.id] = giovanniNpc, [guide.id] = guide }
Game.save.objectToggles[giovanni.map] = {
  VIRIDIANGYM_GIOVANNI = true, REMATCH_SENTINEL = true,
}

local talksBeforeGiovanni = ow.vanillaTalks
Overworld.talkTo(ow, giovanniNpc)
equal(ow.vanillaTalks, talksBeforeGiovanni + 1,
  "direct Giovanni object always delegates to his story script")
local talksBeforeVisibleGuide = ow.vanillaTalks
Overworld.talkTo(ow, guide)
equal(ow.vanillaTalks, talksBeforeVisibleGuide + 1,
  "Viridian guide delegates while Giovanni is visible")

Game.save.objectToggles[giovanni.map].VIRIDIANGYM_GIOVANNI = false
local talksBeforeHiddenGuide = ow.vanillaTalks
Overworld.talkTo(ow, guide)
equal(ow.vanillaTalks, talksBeforeHiddenGuide,
  "hidden Giovanni state enables exact Gym Guide rematch")
local giovanniPrompt = textBoxes[#textBoxes]
check(giovanniPrompt.text:find(giovanni.post, 1, true) ~= nil,
  "Giovanni guide prompt preserves post-battle guidance")
check(giovanniPrompt.text:find("Challenge GIOVANNI\nagain?", 1, true) ~= nil,
  "Giovanni guide asks the explicit rematch question")
giovanniPrompt.opts.choice(true)
local giovanniBattle = pushedBattles[#pushedBattles]
equal(giovanniBattle.oppClass, giovanni.class,
  "Giovanni guide launches OPP_GIOVANNI")
equal(giovanniBattle.partyIndex, 3,
  "Giovanni guide launches Viridian party #3")
equal(giovanniBattle.checkpointOrigin.npcId, giovanni.guideId,
  "Giovanni checkpoint resumes through the guide object")
equal(giovanniBattle.checkpointOrigin.trainerForfeitIdentity, giovanni.leaderId,
  "Giovanni checkpoint records synthetic leader identity")
equal(dialogueCalls.lastContext.npcId, giovanni.leaderId,
  "Giovanni journey context uses synthetic leader ID")
equal(dialogueCalls.lastContext.npcName, giovanni.leaderName,
  "Giovanni journey context uses synthetic leader name")
equal(dialogueCalls.lastBefore.npcId, giovanni.leaderId,
  "Giovanni preparation memory uses synthetic leader ID")
equal(dialogueCalls.lastBefore.cellX, 2,
  "Giovanni synthetic memory uses canonical X")
equal(dialogueCalls.lastBefore.cellY, 1,
  "Giovanni synthetic memory uses canonical Y")
giovanniBattle.onFinish("win")
equal(Game.save.flags[giovanni.flag], nil,
  "Giovanni rematch does not synthesize the recomp-local victory flag")
equal(Game.save.flags.EVENT_BEAT_VIRIDIAN_GYM_GIOVANNI, true,
  "Giovanni rematch preserves the cartridge-imported victory flag")
equal(Game.save.flags[giovanni.gotFlag], true,
  "Giovanni rematch win preserves TM completion flag")
equal(Game.save.inventory[giovanni.badge], 1,
  "Giovanni rematch win preserves Earth Badge")
equal(Game.save.objectToggles[giovanni.map].VIRIDIANGYM_GIOVANNI, false,
  "Giovanni rematch never respawns him")
equal(Game.save.objectToggles[giovanni.map].REMATCH_SENTINEL, true,
  "Giovanni rematch leaves unrelated toggles untouched")

local giovanniRestored = BattleState.newTrainer(Game, giovanni.class, 3)
local giovanniOrigin = {
  kind = "trainer_encounter", map = giovanni.map, npcId = giovanni.guideId,
  trainerClass = giovanni.class, partyIndex = 3,
  trainerForfeitIdentity = giovanni.leaderId,
  trainerForfeitRematch = true,
}
equal(Overworld.restoreBattleContinuation(ow, giovanniRestored, giovanniOrigin), true,
  "Giovanni guide checkpoint restores with synthetic identity")
giovanniRestored.onFinish("win")

local tamperedGiovanni = BattleState.newTrainer(Game, giovanni.class, 3)
giovanniOrigin.trainerForfeitIdentity = giovanni.guideId
local vanillaBeforeGiovanniTamper = ow.vanillaRestores
equal(Overworld.restoreBattleContinuation(ow, tamperedGiovanni, giovanniOrigin), false,
  "tampered Giovanni synthetic identity fails closed")
equal(ow.vanillaRestores, vanillaBeforeGiovanniTamper,
  "tampered Giovanni checkpoint never reaches reward-bearing restore")

-- Rivals and other map-script trainers remain excluded.
selectMap("ROUTE_22", "Route22")
local rival = npc("ROUTE_22_obj_1", 1, "OPP_RIVAL1")
Game.save.defeatedTrainers[rival.id] = true
local talksBeforeRival = ow.vanillaTalks
Overworld.talkTo(ow, rival)
equal(ow.vanillaTalks, talksBeforeRival + 1, "rival is excluded")

selectMap("ROCKET_HIDEOUT_B4F", "RocketHideoutB4F")
local scriptedNpc = npc("ROCKET_HIDEOUT_B4F_obj_3", 3, "OPP_ROCKET", "TEXT_SCRIPTED")
Game.save.defeatedTrainers[scriptedNpc.id] = true
local talksBeforeScripted = ow.vanillaTalks
Overworld.talkTo(ow, scriptedNpc)
equal(ow.vanillaTalks, talksBeforeScripted + 1,
  "map-script trainer is excluded")

emit("world.trainer_engaged", { npc = scriptedNpc, trainerClass = "OPP_ROCKET", partyIndex = 1 })
local storyBattle = BattleState.newTrainer(Game, "OPP_ROCKET", 1)
local storyRun = storyBattle.tryRun
emit("battle.started", { battle = storyBattle, kind = "trainer" })
equal(storyBattle.tryRun, storyRun, "map-script forfeit is excluded")

local function checkStoryBossExcluded(label, mapId, id, class, party, text)
  selectMap(mapId, mapId)
  local target = npc(id, 1, class, text or "TEXT_GENERIC", nil, party)
  Game.save.defeatedTrainers[id] = true
  local talksBefore = ow.vanillaTalks
  Overworld.talkTo(ow, target)
  equal(ow.vanillaTalks, talksBefore + 1,
    label .. " cannot enter rematch talk")

  emit("world.trainer_engaged", {
    npc = target, trainerClass = class, partyIndex = party,
  })
  local battle = BattleState.newTrainer(Game, class, party)
  local rawRun = battle.tryRun
  emit("battle.started", { battle = battle, kind = "trainer" })
  equal(battle.tryRun, rawRun, label .. " cannot buy a story-battle forfeit")
  emit("battle.ended", { battle = battle, result = "win" })
end

checkStoryBossExcluded("Rocket Hideout Giovanni #1", "ROCKET_HIDEOUT_B4F",
  "ROCKET_HIDEOUT_B4F_obj_4", "OPP_GIOVANNI", 1, "TEXT_SCRIPTED")
checkStoryBossExcluded("Silph Giovanni #2", "SILPH_CO_11F",
  "SILPH_CO_11F_obj_1", "OPP_GIOVANNI", 2, "TEXT_SCRIPTED")
checkStoryBossExcluded("Fighting Dojo Master", "FIGHTING_DOJO",
  "FIGHTING_DOJO_obj_1", "OPP_BLACKBELT", 1)
checkStoryBossExcluded("Elite Four Lorelei", "LORELEIS_ROOM",
  "LORELEIS_ROOM_obj_1", "OPP_LORELEI", 1)

-- Undefeated generic engagement still receives the paid RUN flow.
selectMap("ROUTE_3", "Route3")
emit("world.trainer_engaged", { npc = unbeaten, trainerClass = "OPP_YOUNGSTER", partyIndex = 1 })
local regularBattle = BattleState.newTrainer(Game, "OPP_YOUNGSTER", 1)
local regularRun = regularBattle.tryRun
emit("battle.started", { battle = regularBattle, kind = "trainer" })
check(regularBattle.tryRun ~= regularRun, "ordinary first battle gets forfeit")
local moneyBeforeDeclined = Game.save.money
regularBattle:tryRun(); regularBattle.queue[1].callback(false)
equal(Game.save.money, moneyBeforeDeclined, "declined forfeit remains free")
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
