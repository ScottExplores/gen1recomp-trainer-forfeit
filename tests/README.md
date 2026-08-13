# Tests

Run the focused trainer-forfeit and rematch suite from the mod directory:

```text
luajit tests/main.lua
luajit tests/dialogue.lua
```

The focused suite covers the ¥200 confirmation flow, ordinary-trainer pairing,
rematch eligibility and exclusions, adaptive dialogue context, namespaced
memory, cleanup, and protection against repeated story rewards. The current
suites contain 76 core/rematch checks and 46 dialogue checks.

`full_load.lua` is a production API-2 loader smoke test. Run it from a
Gen1Recomp checkout, passing the directory that contains `trainer_forfeit`.
It checks the final v0.2.1 manifest, option defaults, exported feature status,
and cleanup through the real loader (15 checks per engine fixture).

Before release, run the focused suite and full-load smoke against Gen1Recomp
0.1.75 and the current supported development checkout. Then run Modkit
validation, ROM-content lint, packaging, ZIP-root inspection, and a loader
smoke test against the extracted ZIP.
