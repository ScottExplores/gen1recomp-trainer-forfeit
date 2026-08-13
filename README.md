# Trainer Forfeit & Rematches

A standalone Gen1Recomp mod for Red, Blue, and Yellow. It keeps the original
¥200 trainer-forfeit feature and lets you revisit defeated ordinary trainers
for safe rematches with journey-aware dialogue.

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

Story-scripted encounters are excluded. Rivals, Gym Leaders, Giovanni,
cutscene battles, trainers with one-time victory rewards, and trainers whose
conversation is owned by a map script retain their original behavior. Wild,
Safari, link, static-Pokémon, and demo battles are untouched.

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

Import `trainer_forfeit-0.2.1.zip` through Gen1Recomp's mod manager, enable it,
and restart the game. Version 0.2.1 keeps the same mod ID as earlier releases,
so importing it is an upgrade rather than a second mod.

Version 0.2.1 is the one-time updater bootstrap release. After it is installed,
Gen1Recomp can check the public GitHub Releases feed and offer future updates
from inside the mod manager.

Do not enable this together with **Scott Mod**, which contains the original
forfeit feature and declares a conflict with this standalone package.

Requires Gen1Recomp 0.1.75 or newer. The editable source is MIT licensed; no
Pokémon ROM text or graphics are bundled in the mod.

## Technical safety notes

The mod wraps only live ordinary-trainer seams and restores its wrappers during
cleanup. It does not clear base-game progress to manufacture rematches. Its
memory is stored under Gen1Recomp's per-mod save namespace, and disabling the
feature leaves the game's normal defeated-trainer data unchanged.
