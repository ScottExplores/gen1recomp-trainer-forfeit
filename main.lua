-- Trainer Forfeit & Rematches
--
-- RUN may be bought for ¥200 in ordinary trainer encounters.  After an
-- ordinary map trainer has been defeated, talking to that same NPC offers a
-- rematch without clearing story flags or replaying one-time rewards.

local COST = 200
local PATCH_KEY = "_trainerForfeitPaidRun"
local WORLD_PATCH = "_trainerForfeitRematchV2"
local DEFAULT_OPTIONS = {
  rematches = true,
  adaptive_dialogue = true,
  trainer_growth = "gentle",
}

local OPPOSITE = {
  up = "down", down = "up", left = "right", right = "left",
}

local SPECIAL_CLASSES = {
  OPP_RIVAL1 = true, OPP_RIVAL2 = true, OPP_RIVAL3 = true,
  OPP_PROF_OAK = true, OPP_BROCK = true, OPP_MISTY = true,
  OPP_LT_SURGE = true, OPP_ERIKA = true, OPP_KOGA = true,
  OPP_SABRINA = true, OPP_BLAINE = true, OPP_GIOVANNI = true,
  OPP_LORELEI = true, OPP_BRUNO = true, OPP_AGATHA = true,
  OPP_LANCE = true,
}

local function traceback(err)
  if debug and debug.traceback then return debug.traceback(tostring(err), 2) end
  return tostring(err)
end

local function compileOptional(mod, relative)
  if type(mod.read) ~= "function" then return nil end
  local source = mod:read(relative)
  if type(source) ~= "string" then return nil end
  local compile = loadstring or load
  local chunk, err = compile(source, "@" .. tostring(mod.path) .. "/" .. relative)
  if not chunk then return nil, err end
  if setfenv and getfenv then setfenv(chunk, getfenv(1)) end
  local ok, installer = xpcall(chunk, traceback)
  if not ok then return nil, installer end
  if type(installer) ~= "function" then return nil, relative .. " has no installer" end
  local installedOK, api = xpcall(function() return installer(mod) end, traceback)
  if not installedOK then return nil, api end
  return api
end

local function sameEngagement(pending, battle)
  if type(pending) ~= "table" or type(battle) ~= "table" then return false end
  if pending.trainerClass ~= battle.oppClass then return false end
  return (pending.partyIndex or 1) == (battle.partyIndex or 1)
end

local function hasHealthyParty(game)
  local party = game and game.save and game.save.party or {}
  for _, mon in ipairs(party) do
    if (tonumber(mon.hp) or 0) > 0 then return true end
  end
  return false
end

local function cloneData(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local copy = {}
  seen[value] = copy
  for key, item in pairs(value) do
    copy[cloneData(key, seen)] = cloneData(item, seen)
  end
  return setmetatable(copy, getmetatable(value))
end

local function boundedLevel(value)
  value = math.floor(tonumber(value) or 0)
  if value < 2 then return 2 end
  if value > 100 then return 100 end
  return value
end

return function(mod)
  local existing = mod.exports.status
  if type(existing) == "table" and existing.installed then return existing end

  if mod.options and type(mod.options.define) == "function" then
    mod.options:define({
      { key = "rematches", label = "TRAINER REMATCHES", type = "toggle",
        default = DEFAULT_OPTIONS.rematches },
      { key = "adaptive_dialogue", label = "JOURNEY DIALOGUE", type = "toggle",
        default = DEFAULT_OPTIONS.adaptive_dialogue },
      { key = "trainer_growth", label = "TRAINER GROWTH", type = "choice",
        default = DEFAULT_OPTIONS.trainer_growth,
        choices = { { "OFF", "off" }, { "GENTLE", "gentle" } } },
    })
  end

  local function option(key)
    local fallback = DEFAULT_OPTIONS[key]
    if not (mod.options and type(mod.options.get) == "function") then
      return fallback
    end
    local ok, value = pcall(function() return mod.options:get(key) end)
    if not ok or value == nil then return fallback end
    return value
  end

  local feature = {
    installed = true, version = "0.2.1", cost = COST,
    rematches = true, dialogue = false,
    optionDefaults = {
      rematches = DEFAULT_OPTIONS.rematches,
      adaptive_dialogue = DEFAULT_OPTIONS.adaptive_dialogue,
      trainer_growth = DEFAULT_OPTIONS.trainer_growth,
    },
  }
  mod.exports.status = feature

  local dialogue, dialogueErr = compileOptional(mod, "dialogue.lua")
  if type(dialogue) == "table" then
    feature.dialogue = true
  elseif dialogueErr and mod.log and mod.log.warn then
    mod.log:warn("journey dialogue disabled: %s", tostring(dialogueErr))
  end

  local pending
  local active = setmetatable({}, { __mode = "k" })
  local rematchBattles = setmetatable({}, { __mode = "k" })
  local constructingRematch
  local unsubscribe = {}
  local worldPatch

  local okGame, Game = pcall(require, "src.core.Game")
  local okWorld, OverworldState = pcall(require, "src.world.OverworldController")
  local okScripts, mapScripts = pcall(require, "data.scripts.init")
  local okVictories, victories = pcall(require, "data.scripts.victories")
  victories = okVictories and victories or {}

  local function headerFor(ow, npc)
    local game = okGame and Game or nil
    local data = game and game.data
    local label = ow and ow.map and ow.map.def and ow.map.def.label
    local index = npc and npc.def and npc.def.index
    if not (data and type(data.trainerHeader) == "function" and label and index) then
      return nil
    end
    return data:trainerHeader(label, index)
  end

  -- Ordinary means the engine's generic object-event trainer path.  A map
  -- talk script owns its NPC's story choreography and is never intercepted.
  -- Victory-table classes own badges, gifts, doors or story flags and are
  -- excluded even if an object also has an extracted trainer header.
  local function ordinaryTrainer(ow, npc)
    local d = npc and npc.def
    if type(d) ~= "table" or type(d.trainerClass) ~= "string" then return false end
    if SPECIAL_CLASSES[d.trainerClass] then return false end
    if victories[d.trainerClass .. "#" .. tostring(d.trainerParty or 1)] then
      return false
    end
    if not headerFor(ow, npc) then return false end
    if okScripts and mapScripts and type(mapScripts.talkScript) == "function"
        and ow and ow.map and mapScripts.talkScript(ow.map.id, d.text) then
      return false
    end
    return true
  end

  local function overworldFor(npc)
    local ow = okGame and Game.overworld or nil
    if ow and ow.map and npc then return ow end
    return nil
  end

  local function detach(battle)
    if type(battle) ~= "table" then return end
    local record = rawget(battle, PATCH_KEY)
    if type(record) ~= "table" or record.owner ~= mod.id then return end
    if rawget(battle, "tryRun") == record.wrapper then
      rawset(battle, "tryRun", record.rawOriginal)
    end
    rawset(battle, PATCH_KEY, nil)
    active[battle] = nil
  end

  local function recordBattle(game, npc, class, party, result, extra)
    if dialogue and type(dialogue.recordBattle) == "function" then
      local ok, err = pcall(dialogue.recordBattle, dialogue, game, npc, class,
                            party or 1, result, extra or {})
      if not ok and mod.log and mod.log.warn then
        mod.log:warn("journey record failed: %s", tostring(err))
      end
    end
  end

  local function attach(battle, engagement)
    local owned = rawget(battle, PATCH_KEY)
    if type(owned) == "table" then return owned.owner == mod.id end
    local original = battle.tryRun
    if type(original) ~= "function" or type(battle.sayChoice) ~= "function"
       or type(battle.say) ~= "function" then return false end

    local record = {
      owner = mod.id, rawOriginal = rawget(battle, "tryRun"),
      original = original, npc = engagement.npc,
    }
    local function tryRun(self)
      self.phase = "messages"
      self.afterQueue = "menu"
      self:sayChoice("Forfeit battle\nfor ¥200?", function(yes)
        if not yes then return end
        local save = self.game and self.game.save
        local money = save and tonumber(save.money) or 0
        if type(save) ~= "table" or money < COST then
          self:say("Not enough money!\nNeed ¥200.")
          return
        end
        save.money = money - COST
        self.paidTrainerForfeit = true
        local npc = record.npc
        if type(npc) == "table" and OPPOSITE[npc.facing] then
          npc.facing = OPPOSITE[npc.facing]
        end
        self:say("Paid ¥200.\nBattle forfeited!")
        self.result = "run"
        self.afterQueue = "finish"
      end)
    end
    record.wrapper = tryRun
    rawset(battle, PATCH_KEY, record)
    rawset(battle, "tryRun", tryRun)
    active[battle] = true
    return true
  end

  local function startRematch(ow, npc)
    local game = okGame and Game or nil
    local d = npc and npc.def
    if not (game and d) then
      if npc then npc.frozen = false end
      return
    end
    if not hasHealthyParty(game) then
      local TextBox = require("src.render.TextBox")
      game.stack:push(TextBox.new(game, "You need a healthy\nPOKEMON first!",
        function() npc.frozen = false end))
      return
    end

    if dialogue and type(dialogue.beforeRematch) == "function" then
      pcall(dialogue.beforeRematch, dialogue, game, npc, d.trainerClass,
            d.trainerParty or 1)
    end

    local BattleState = require("src.battle.BattleState")
    local engagement = {
      npc = npc, trainerClass = d.trainerClass, partyIndex = d.trainerParty or 1,
    }
    constructingRematch = engagement
    local ok, battle = xpcall(function()
      return BattleState.newTrainer(game, d.trainerClass, d.trainerParty)
    end, traceback)
    constructingRematch = nil
    if not ok then
      npc.frozen = false
      if mod.log and mod.log.warn then mod.log:warn("rematch build failed: %s", battle) end
      return
    end

    battle.trainerForfeitRematch = true
    battle.checkpointOrigin = {
      kind = "trainer_encounter",
      map = ow.map and ow.map.id,
      npcId = npc.id,
      trainerClass = d.trainerClass,
      partyIndex = d.trainerParty or 1,
      trainerForfeitRematch = true,
    }
    rematchBattles[battle] = engagement
    battle.onFinish = function(result)
      recordBattle(game, npc, d.trainerClass, d.trainerParty or 1, result, {
        isRematch = true, paidForfeit = battle.paidTrainerForfeit == true,
      })
      rematchBattles[battle] = nil
      ow:afterBattle(result, battle)
      ow.engaging = false
      npc.frozen = false
    end
    ow:pushBattle(battle)
  end

  if okWorld and type(OverworldState) == "table"
      and type(OverworldState.talkTo) == "function" then
    local existingPatch = rawget(OverworldState, WORLD_PATCH)
    if type(existingPatch) == "table" and existingPatch.active then
      error("trainer rematch adapter is already active", 0)
    end
    worldPatch = { owner = mod.id, active = true, original = OverworldState.talkTo }
    worldPatch.wrapper = function(ow, npc, ...)
      if not worldPatch.active or option("rematches") ~= true
          or not ordinaryTrainer(ow, npc)
          or not ow:trainerDefeated(npc) then
        return worldPatch.original(ow, npc, ...)
      end
      npc.frozen = true
      npc:facePlayer(ow.player)
      local d = npc.def
      local header = headerFor(ow, npc)
      local baseText = header and header.after and Game.data.text[header.after]
        or "I've been training\nsince our last battle!"
      local journey
      if option("adaptive_dialogue") == true
          and dialogue and type(dialogue.context) == "function" then
        local ok, context = pcall(dialogue.context, dialogue, Game, npc,
                                  d.trainerClass, d.trainerParty or 1)
        if ok and type(context) == "table" then journey = context.text end
      end
      local question = baseText
      if journey and journey ~= "" and journey ~= baseText then
        question = question .. "\f" .. journey
      end
      question = question .. "\fWant a rematch?"
      local TextBox = require("src.render.TextBox")
      Game.stack:push(TextBox.new(Game, question, nil, {
        choice = function(yes)
          if yes then startRematch(ow, npc) else npc.frozen = false end
        end,
      }))
    end
    rawset(OverworldState, WORLD_PATCH, worldPatch)
    OverworldState.talkTo = worldPatch.wrapper

    -- Gen1Recomp 0.1.80 can restore trainer battles from checkpoints.  Its
    -- stock trainer continuation awards victory flags/rewards, which is
    -- correct for a first encounter but unsafe for a rematch.  Recognize only
    -- our explicit marker and rebuild the reward-free continuation.
    if type(OverworldState.restoreBattleContinuation) == "function" then
      worldPatch.restoreOriginal = OverworldState.restoreBattleContinuation
      worldPatch.restoreWrapper = function(ow, battle, origin)
        if not worldPatch.active or type(origin) ~= "table"
            or origin.trainerForfeitRematch ~= true then
          return worldPatch.restoreOriginal(ow, battle, origin)
        end
        if origin.kind ~= "trainer_encounter" or type(battle) ~= "table"
            or battle.kind ~= "trainer" or not ow.map
            or origin.map ~= ow.map.id
            or origin.trainerClass ~= battle.oppClass
            or (origin.partyIndex or 1) ~= (battle.partyIndex or 1)
            or type(origin.npcId) ~= "string" then
          return false
        end
        local npc = ow.npcPool and ow.npcPool[origin.npcId] or nil
        if not npc or not ordinaryTrainer(ow, npc)
            or not ow:trainerDefeated(npc) then
          return false
        end
        local d = npc.def
        local engagement = {
          npc = npc, trainerClass = d.trainerClass,
          partyIndex = d.trainerParty or 1,
        }
        battle.trainerForfeitRematch = true
        rematchBattles[battle] = engagement
        attach(battle, engagement)
        battle.onFinish = function(result)
          recordBattle(battle.game or Game, npc, d.trainerClass,
            d.trainerParty or 1, result, {
              isRematch = true,
              paidForfeit = battle.paidTrainerForfeit == true,
            })
          rematchBattles[battle] = nil
          ow:afterBattle(result, battle)
          ow.engaging = false
          npc.frozen = false
        end
        return true
      end
      OverworldState.restoreBattleContinuation = worldPatch.restoreWrapper
    end
  else
    feature.rematches = false
  end

  if mod.hooks and type(mod.hooks.wrap) == "function" then
    unsubscribe[#unsubscribe + 1] = mod.hooks:wrap("trainer.party",
      function(nextFn, class, party, partyDef)
        local built = nextFn(class, party, partyDef)
        local tag = constructingRematch
        if not tag or tag.trainerClass ~= class
            or tag.partyIndex ~= (party or 1) then return built end
        local isolated = cloneData(built)
        if option("trainer_growth") == "gentle"
            and dialogue and type(dialogue.rematchBoost) == "function" then
          local ok, descriptor = pcall(dialogue.rematchBoost, dialogue, Game,
            tag.npc, class, party or 1, built)
          if ok and type(descriptor) == "table" then
            if type(descriptor.levels) == "table" then
              for rawSlot, rawTarget in pairs(descriptor.levels) do
                local slotIndex = tonumber(rawSlot)
                if slotIndex and slotIndex == math.floor(slotIndex)
                    and type(isolated[slotIndex]) == "table" then
                  local current = tonumber(isolated[slotIndex].level) or 0
                  local target = boundedLevel(rawTarget)
                  if target > current then isolated[slotIndex].level = target end
                end
              end
            elseif tonumber(descriptor.levelBonus) then
              local bonus = tonumber(descriptor.levelBonus)
              for _, slot in ipairs(isolated) do
                local current = tonumber(slot.level) or 0
                local target = boundedLevel(current + bonus)
                if target > current then slot.level = target end
              end
            end
          end
        end
        return isolated
      end, 200)
  end

  unsubscribe[#unsubscribe + 1] = mod.events:on("world.trainer_engaged", function(event)
    if type(event) ~= "table" or type(event.npc) ~= "table"
        or not ordinaryTrainer(overworldFor(event.npc), event.npc) then
      pending = nil
      return
    end
    pending = { npc = event.npc, trainerClass = event.trainerClass,
                partyIndex = event.partyIndex }
  end)

  unsubscribe[#unsubscribe + 1] = mod.events:on("battle.started", function(event)
    local battle = type(event) == "table" and event.battle or nil
    if type(battle) ~= "table" then pending = nil return end
    local engagement
    if rematchBattles[battle] then
      engagement = rematchBattles[battle]
    else
      engagement, pending = pending, nil
    end
    local kind = event.kind or (battle.battleKind and battle:battleKind())
    if kind == "trainer" and sameEngagement(engagement, battle) then
      attach(battle, engagement)
    end
  end)

  unsubscribe[#unsubscribe + 1] = mod.events:on("battle.ended", function(event)
    pending = nil
    local battle = type(event) == "table" and event.battle or nil
    if battle and not rematchBattles[battle] then
      local record = rawget(battle, PATCH_KEY)
      if record and record.npc then
        recordBattle(battle.game, record.npc, battle.oppClass,
          battle.partyIndex or 1, event.result, {
            isRematch = false, paidForfeit = battle.paidTrainerForfeit == true,
          })
      end
    end
    detach(battle)
  end)

  function feature.cleanup()
    if not feature.installed then return end
    feature.installed = false
    pending, constructingRematch = nil, nil
    for battle in pairs(active) do detach(battle) end
    for _, stop in ipairs(unsubscribe) do
      if type(stop) == "function" then pcall(stop) end
    end
    if worldPatch then
      worldPatch.active = false
      if OverworldState.talkTo == worldPatch.wrapper then
        OverworldState.talkTo = worldPatch.original
      end
      if rawget(OverworldState, WORLD_PATCH) == worldPatch then
        rawset(OverworldState, WORLD_PATCH, nil)
      end
      if worldPatch.restoreWrapper
          and OverworldState.restoreBattleContinuation == worldPatch.restoreWrapper then
        OverworldState.restoreBattleContinuation = worldPatch.restoreOriginal
      end
    end
    if dialogue and type(dialogue.cleanup) == "function" then pcall(dialogue.cleanup, dialogue) end
  end

  return feature
end
