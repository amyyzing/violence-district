# Cateyes

A compact interface for Violence District. Click a feature row once to toggle it.
The small indicator rotates and lights up when enabled.

| Feature | Hotkey |
| --- | --- |
| Highlights | Y |
| Skill check | G |
| Projectile preview | H |

Choose **Normal** or **Perfect** beside **Skill mode**. Drag the title to move
the panel. **Right Control** or the minus button hides it; the floating **CE**
button reopens it. The panel automatically fits smaller viewports.

Skill checks react to needle rotation updates and use the game's full great-hit
window. Perfect mode aims near its center; if a fast frame skips the great
window, either mode takes a valid normal hit when possible. Frame stalls that
skip both windows and executor input delays can still cause misses.

Highlights also show generator progress, for example `42.3/100 (42.3%)`.
Labels sit above the generator hitbox and scale with distance and camera zoom.
They update with repair progress and disappear on completion, removal, or when
Highlights is turned off. The fraction uses the game's 0–100 progress scale.
Generator paths and the F hotkey have been removed.

The GUI uses maximum display order in CoreGui when supported by the executor,
with a fallback to its hidden UI container or PlayerGui.

Mouse control stays with the game. The panel uses native modal UI while visible;
hiding, disabling, or destroying it removes that modal state. It never writes
`MouseBehavior` or `MouseIconEnabled`, or restores an old camera snapshot.

## Local build

Run `node scripts/build_bundle.mjs` to produce `build/violence-district.luau`.
Execute that file's contents in the connected client. It includes all three
feature modules. Rerunning preserves switches, skill mode, panel position,
and visibility, and replaces the old GUI.

Both `loader.luau` and `dev_loader.luau` fetch the current main branch. The normal
loader previously fetched v0.1.10 (logic 58), which omitted the newer spear fixes.
The standalone build lets you run local changes before pushing them.

## Checks

- `node scripts/check_luau_syntax.mjs` checks source syntax.
- `scripts/test_skill_check.luau` returns a test function accepting the
  skill-check factory. It uses isolated GUI fixtures and records input without
  sending keys to the game, including continuous rotations used by King's Scourge.
- `scripts/test_gui.luau` returns a test function for the loaded GUI. It invokes
  its callbacks, checks mouse ownership, and restores the settings.
- `scripts/test_visual_features.luau` returns a test function requiring a loaded
  map. It checks generator label formatting, proportional placement, highlight
  lifecycle, projectile cleanup, and path API removal, then restores the switches.
- `lua scripts/test_offline.luau` checks label data and legacy upgrade behavior
  using simple doubles, plus 16 free-flight speed/frame-rate cases and four
  recorded flying-spear traces. It does not validate Roblox rendering or collisions.
- `scripts/test_projectile_aim.luau` checks recorded launch directions, gravity,
  frame timing, charge range, collisions, camera-spear attachment, and cleanup
  using isolated fixtures, including walls behind multiple non-colliding parts
  and thin walls beside them. It does not send throws.

The spear preview restores the earlier curved trajectory. It keeps the game's
release offset for collision prediction and uses the camera spear's Hitbox as
the visible line start when available. Four live throws confirmed half gravity
and the full/mid speeds of 165/142.5 studs per second. Direction follows the
camera, matching the game's `Lookvectorgiver`, rather than converging on nearby
geometry. The game sends that direction every 0.1 seconds, so quick turns,
latency, future target movement, and changes in frame timing can affect accuracy.

These checks cover local behavior; actual skill-input delivery and projectile
accuracy also depend on the executor and the current game mechanics.

The October 9 compatibility audit used live place version **10392**. Generator
and hook discovery, team colors, completed-generator cleanup, and live path
construction passed. Current generator/healing scripts still accept relative
angles from 102 through 116 degrees; the helper uses that full window and
compares absolute rotations exactly as the game does. Old-character
animation and spear-mode callbacks can no longer clear a new character's preview.
GUI and projectile fixtures passed; actual Veil impacts and skill-input delivery
were not exercised in gameplay during that audit. Path construction described
above is historical; that feature has since been removed.

The October 15 changes passed live generator-label lifecycle and 36 GUI
assertions after upgrading a connected client from logic 58.

A subsequent four-minute Veil capture recorded seven launches. Medium/full
speeds were 142.5/165, with gravity multiplier 0.5. Four flying-model traces fit
velocity-first integration within 0.002 studs; moving-camera samples differed
from launch directions by as much as 9 degrees. Capture data is stored in
`scripts/fixtures/veil_2026_10_15.luau` and can be passed to the projectile test.
Input durations and retained power-label text are observational and can include
cooldown or post-release time; they do not prove a different charge threshold.

The preview now preserves the first physical segment instead of joining the
held spear directly to the 0.1-second sample, and samples the arc every 0.05
seconds. Rendered-curve interpolation stayed within 0.05 studs of those flight
traces. This validates the flight curve, not future moving-target hits or every
collision surface; low-charge throws below the medium tier still need capture.

The solver normalizes the input direction before applying speed, matching
`ProjectileHandler`. Regression checks also verify both endpoints of every
physical arc segment against the calculated flight positions. The short link
from the held spear to the release point is cosmetic and does not alter physics.
