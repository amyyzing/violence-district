# Cateyes

A compact interface for Violence District. Click a feature row once to toggle it.
The small indicator rotates and lights up when enabled.

| Feature | Hotkey |
| --- | --- |
| Highlights | Y |
| Skill check | G |
| Generator paths | F |
| Projectile preview | H |

Choose **Normal** or **Perfect** beside **Skill mode**. Drag the title to move
the panel. **Right Control** or the minus button hides it; the floating **CE**
button reopens it. The panel automatically fits smaller viewports.

The GUI uses maximum display order in CoreGui when supported by the executor,
with a fallback to its hidden UI container or PlayerGui.

Mouse control stays with the game. The panel uses native modal UI while visible;
hiding, disabling, or destroying it removes that modal state. It never writes
`MouseBehavior` or `MouseIconEnabled`, or restores an old camera snapshot.

## Local build

Run `node scripts/build_bundle.mjs` to produce `build/violence-district.luau`.
Execute that file's contents in the connected client. It includes all four
feature modules. Rerunning preserves switches, skill mode, panel position,
and visibility, and replaces the old GUI.

The release loader remains pinned to its published release. The standalone
build lets you run local changes before publishing a release.

## Checks

- `node scripts/check_luau_syntax.mjs` checks source syntax.
- `scripts/test_skill_check.luau` returns a test function accepting the
  skill-check factory. It uses isolated GUI fixtures and records input without
  sending keys to the game.
- `scripts/test_gui.luau` returns a test function for the loaded GUI. It invokes
  its callbacks, checks mouse ownership, and restores the settings.
- `scripts/test_visual_features.luau` returns a test function requiring a loaded
  map. It checks owned fixtures, live path construction, cleanup, and recovery
  from one deliberately injected path error, then restores the switches.

These checks cover local behavior; actual skill-input delivery and projectile
accuracy also depend on the executor and the current game mechanics.
