# Changelog

## 0.2.1 - 2026-08-13

- Added the public GitHub repository identifier used by Gen1Recomp's built-in
  release update checker.
- No gameplay behavior changed from 0.2.0.

## 0.2.0

- Adds opt-in rematches when talking to defeated ordinary map trainers.
- Adds offline, journey-aware trainer dialogue with namespaced rematch memory.
- Adds **Rematches**, **Adaptive Dialogue**, and **Trainer Growth** settings.
- Adds optional gentle, per-battle rematch growth without modifying the
  original trainer roster data.
- Preserves defeated and story flags during rematches, preventing repeat
  badges, TMs, key items, map changes, and one-time victory hooks.
- Excludes rivals, leaders, scripted encounters, one-time reward trainers,
  wild battles, Safari battles, link battles, and demos from the rematch path.
- Keeps the fixed ¥200 paid-forfeit flow available in eligible original
  encounters and rematches.

## 0.1.0

- Adds a fixed ¥200 confirmation prompt when RUN is selected in ordinary
  trainer battles.
- Preserves wild and scripted story-battle behavior.
- Prevents an undefeated sight trainer from instantly re-engaging.
