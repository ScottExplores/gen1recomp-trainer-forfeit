# Trainer Forfeit & Rematches

A standalone Gen1Recomp mod for Red, Blue, and Yellow. It keeps the original
¥200 trainer-forfeit feature and lets you revisit defeated ordinary trainers
and all eight Gym Leaders for safe rematches with journey-aware dialogue.

## Features

### Paid trainer forfeits

- Choose **RUN** during an ordinary trainer encounter.
- Confirm **YES** and pay exactly **¥200** to leave the battle.
- Choosing **NO**, or having less than ¥200, costs nothing and leaves the
  battle active.
- A successful forfeit awards no victory, causes no blackout, and applies no
  ordinary loss penalty.
- Sight trainers temporarily turn away so they cannot immediately engage
  again. Walking up and talking to them still works.

### Safe trainer rematches

Talk to an already defeated ordinary map trainer to hear their current line
and receive a rematch prompt. Accepting starts a fresh trainer battle; declining
returns control immediately.

Rematches deliberately leave the trainer's original defeated flag and story
event flags intact. They never repeat badges, TMs, key items, map changes,
one-time victory hooks, or other story rewards. Normal battle experience and
money continue to follow Gen1Recomp's active battle rules and compatible mods.
The ¥200 RUN option is also available inside an eligible rematch.

### Gym Leader rematches

After a Gym Leader's original badge and TM sequence is fully complete, talk to
Brock, Misty, Lt. Surge, Erika, Koga, Sabrina, or Blaine again to receive the
same safe rematch prompt. Their first story battle remains completely vanilla:
the mod does not add paid RUN there and does not interfere with their badge,
TM, dialogue, or gym-event sequence.

If the bag was full when a leader first tried to give their TM, the mod leaves
their conversation alone until that TM is successfully received. This keeps
the original retry path intact instead of accidentally replacing an owed
reward with a rematch prompt.

Giovanni still gives his farewell and leaves Viridian Gym exactly as intended.
After he is gone, talk to the permanent Viridian Gym guide to challenge
Giovanni's Gym roster again. The mod never respawns Giovanni or changes his
saved hide flag.

Other story-scripted encounters are excluded. Rivals, Rocket-boss Giovanni
parties, the Fighting Dojo Master, Elite Four, cutscene battles, other trainers
with one-time victory rewards, and trainers whose conversation is owned by a
map script retain their original behavior. Wild, Safari, link, static-Pokémon,
and demo battles are untouched.

### Offline adaptive dialogue

The trainer dialogue is a small local context engine, not a cloud AI service.
It selects handcrafted lines using only facts already in the current save and
map, such as rematch history and nearby defeated trainers. It does not use the
internet, send gameplay data anywhere, require an account, or need an API key.

Older saves do not contain a historical timeline for victories earned before
the mod was installed. Dialogue initially uses current journey facts such as
badges and party strength, then builds its own namespaced trainer memory as you
keep playing.

## Settings

Open Gen1Recomp's mod settings for **Trainer Forfeit & Rematches**:

- **Rematches** — enables or disables repeat battles while preserving paid
  forfeits.
- **Adaptive Dialogue** — uses journey-aware lines when enabled and a simple
  rematch invitation after the trainer's normal defeated line when disabled.
- **Trainer Growth** — **Gentle** lets repeat opponents improve modestly from
  their original roster as your shared rematch history grows; **Off** always
  uses their original levels. Growth is calculated for that battle only and
  never rewrites the base trainer data.

Rematches and adaptive dialogue default to on; trainer growth defaults to
gentle. All three can be changed without starting a new save.

## Install or upgrade

Install version 0.2.1 or newer once, then open Gen1Recomp's mod manager and use
**Update** when version 0.3.0 is offered. The updater downloads
`trainer_forfeit-0.3.0.zip`, keeps the same `trainer_forfeit` mod ID, and
preserves the mod's settings and journey memory.

For a fresh install, import `trainer_forfeit-0.3.0.zip` through the puzzle-piece
mod manager, enable it, and restart the game. Version 0.2.1 was the one-time
updater bootstrap, so users already on it do not need to manually move this ZIP.

Do not enable this together with **Scott Mod**, which contains the original
forfeit feature and declares a conflict with this standalone package.

Requires Gen1Recomp 0.1.75 or newer. The editable source is MIT licensed; no
Pokémon ROM text or graphics are bundled in the mod.

## Technical safety notes

The mod wraps only live trainer-talk seams and restores its wrappers during
cleanup. It does not clear base-game progress, respawn story NPCs, or call the
engine's badge/TM victory continuation to manufacture rematches. Leader
eligibility requires an exact map, NPC, class, party, victory flag, badge, and
completed TM handoff. Its memory is stored under Gen1Recomp's per-mod save
namespace, and disabling the feature leaves normal progress unchanged.
