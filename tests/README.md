# Tests

Run the focused trainer-forfeit and rematch suite from the mod directory:

```text
luajit tests/main.lua
luajit tests/dialogue.lua
```

The focused suite covers the ¥200 confirmation flow, ordinary-trainer pairing,
all seven persistent Gym Leader mappings, Giovanni's hidden-state Gym Guide
rematch, imported-save completion checks, badge/TM/flag/object-toggle reward
safety, checkpoint tamper rejection, boss exclusions, adaptive dialogue
context, namespaced memory, and cleanup. The current suites contain 266
core/rematch checks and 46 dialogue checks.

`full_load.lua` is a production API-2 loader smoke test. Run it from a
Gen1Recomp checkout, passing the directory that contains `trainer_forfeit`.
It checks the final v0.3.0 manifest, option defaults, exported feature status,
and cleanup through the real loader (16 checks per engine fixture).

Before release, run the focused suite and full-load smoke against Gen1Recomp
0.1.75 and the current supported development checkout. Then run Modkit
validation, ROM-content lint, packaging, ZIP-root inspection, and a loader
smoke test against the extracted ZIP.
