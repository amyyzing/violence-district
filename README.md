# Cateyes

A compact interface for Violence District. Click a feature row once to toggle it.
The small indicator rotates and lights up when enabled.
Projectile preview and Spear aim are greyed out unless you are Veil on the Killer
team. Auto parry is greyed out unless you are a survivor with an equipped dagger.
Rows remain toggleable while greyed out, including through their hotkeys. An
enabled switch remembers your preference and becomes active when its requirements
are met. The rows refresh as your role, character or equipped item changes.

| Feature | Hotkey |
| --- | --- |
| Highlights | Y |
| Skill check | G |
| Projectile preview | H |
| Spear aim | J |
| Auto parry | K |

Choose **Normal** or **Perfect** beside the healing counter; the selection slides
between modes. Drag the exposed menu background to move the panel. **Right Control**
maximizes or minimizes the same panel into its icon cube in 0.4 seconds.
The minimized cube is also draggable and remembers its own position across reloads.
The panel automatically fits smaller viewports.

Skill checks react to needle rotation updates and use the game's full great-hit
window. Perfect mode aims near its center; if a fast frame skips the great
window, either mode takes a valid normal hit when possible. Frame stalls that
skip both windows can still cause misses.
Skill checks call the current character's native generator/healing keyboard
handlers directly, so simulated Space input, mouse capture and Roblox menu
keyboard routing are not required. The game still evaluates the real needle
angle and handles its own results. Native callback discovery is cached per
character and cleared on respawn; unsupported discovery reports a warning
instead of sending input into the menu.

The healing counter beside the mode buttons follows the character's live
`HealProgress` attribute on a 0–100 scale, including Ambitious Medic progress.
It shows 100/100 when fully healed and a dash when progress is unavailable.

Highlights also show generator progress, for example `42.3/100 (42.3%)`.
Labels sit above the generator hitbox and scale with distance and camera zoom.
They update with repair progress and disappear on completion, removal, or when
Highlights is turned off. The fraction uses the game's 0–100 progress scale.
Generator paths and the F hotkey have been removed.

**Spear aim** starts off. Enable it with **J** or its row, then charge a Veil
throw. It selects the standing survivor nearest the cursor on screen and keeps
that target for the charge. The intercept uses the current charge speed,
filtered movement velocity, half gravity, velocity-first integration, and an estimated
one-way network delay. The camera follows the launch direction until 0.15 seconds
after release; switching weapons, losing focus, or disabling the feature releases
it immediately. The feature never throws or sends a weapon remote for you.
Targets that turn, accelerate, jump, or move behind obstacles can still be missed.
No camera solution is applied when a target is unreachable at the current charge.

**Auto parry** starts off. Enable it with **K** or its row while playing survivor.
An identified melee attack or lunge-hold animation triggers the equipped dagger's
existing `ParryClient` when its killer is within 13 studs. Native readiness checks
still apply, including cooldown, silence, health and other actions. Each observed
attack gets at most one attempt. Recognized melee hold/lunge cues remain active
while their animation is playing, so entering 13 studs after a long hold can
trigger parry. Ordinary swing cues still expire after 0.8 seconds. Stopping the
hold, changing character/role, or dying clears the cue. The inspected Veil melee and Jeff attack/lunge/Frenzy animation IDs and the
shared `attack`/`lungehold` track names are recognized, including generic replicated
`Animation` tracks with those IDs; custom attacks with other
names/IDs are not guessed. Detection depends on animation replication reaching you.
The Heartbeat monitor runs only while an attack cue may enter range. Character
parts are cached and the range check uses squared distance. Native readiness is
checked once when the cue reaches 13 studs; a rejected cue waits for the next
attack instead of retrying each frame. No frame loop runs while idle or awaiting
the result. Animation listeners attach only to killers. The native dagger client
is cached from its result-event callback during setup/equip, with bounded setup
retries; attack processing never scans input callbacks or discovers that client.

Parry diagnostics expose **Call** (observed attack cue to native parry call) and
**reply** (call to receipt of `parryResult`), plus success/failure. Reply time includes
network travel, server handling and the parry resolution window; it is not a server
processing time or a one-way latency measurement. No server timestamp is exposed
by this result signal. The last 12 samples are available through
`getgenv().ViolenceDistrictLogic.getParryDiagnostics()`. Its `lastBlocked` entry
retains the latest rejected in-range cue, with its reason, animation, distance,
and observation time, even after earlier successful attempts. Only one blocked
entry is retained; it does not add polling or bypass native readiness.

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

Both `loader.luau` and `dev_loader.luau` fetch the current main branch. The normal
loader previously fetched v0.1.10 (logic 58), which omitted the newer spear fixes.
The standalone build lets you run local changes before pushing them.

## Checks

- `node scripts/check_luau_syntax.mjs` checks source syntax.
- `scripts/test_auto_parry.luau` uses isolated signals and a native-client double
  to check range, readiness, request/reply timing, repeated cues and cleanup.
  It does not parry or send remotes in the live game.
- `scripts/test_spear_aim.luau` checks interception against a separate stepwise
  flight simulation, unreachable targets, cursor selection, and invalid targets.
- `scripts/test_spear_aim_lifecycle.luau` uses a fake camera and render scheduler
  to check charge/release speed, weapon switching, disabling, and cleanup.
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
release offset for collision prediction and the visible arc start.
Four live throws confirmed half gravity
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

The same saved capture contains two long-flight stop endpoints. Horizontal
travel implies flight times of about 3.52 and 3.61 seconds; their vertical drop
implies acceleration of 98.28 and 98.17 studs/s². The offline checks compare
those endpoints with the predicted curve within 1.5 studs. This supports half
world gravity for that capture, but does not establish current-game collision
timing or explain the reported visual mismatch. A fresh impact capture is still
needed before changing the gravity constant.

The preview now preserves the first physical segment instead of joining the
held spear directly to the 0.1-second sample, and samples the arc every 0.05
seconds. Rendered-curve interpolation stayed within 0.05 studs of those flight
traces. This validates the flight curve, not future moving-target hits or every
collision surface; low-charge throws below the medium tier still need capture.

The preview checks the Veil ability HUD before predicting the full charged
throw. During its cooldown, a long hold stays at 142.5 speed. A ready full charge
uses 165 and predicts through world geometry while still stopping at characters.

The visible guide is a continuous fading line over the first 1.35 seconds of
flight, sampled every 0.025 seconds for smoother curvature. Dotted path markers
have been removed. Collision prediction still checks the full four-second
flight; this presentation does not exaggerate gravity or lift.

The solver normalizes the input direction before applying speed, matching
`ProjectileHandler`. Regression checks also verify both endpoints of every
physical arc segment against the calculated flight positions. The straight
cosmetic link from the held spear to the release point has been removed; only
the sampled flight arc and its impact marker are visible.
The guide starts at the game's projectile spawn point. The held first-person
weapon can sit elsewhere on screen; no visual offset is blended into flight samples.

An October 16 live render probe found the Heartbeat-driven guide could trail the
camera's horizontal aim by 6.45 degrees during turns. The guide now updates at
camera render priority + 1 and unbinds when charging ends, disabled, or destroyed.
An observer immediately after that update measured a maximum difference of
0.04 degrees across 990 frames, versus 6.45 across 1,123 baseline frames.
This checks camera alignment; it does not prove exact impact prediction.

Collision previews ignore fully transparent and non-colliding parts, including
generator bodies and character hitboxes that meet either condition. This is a
display filter; the game can still register impacts on some excluded parts.

Arc lines and the smaller impact marker now use normal scene depth rather
than drawing through walls. The projectile target highlight is also occluded.
Ordinary trajectories stop at valid collisions; powered trajectories retain the
game's wall piercing, with hidden portions obscured by world geometry.

An October 18 round capture identified Jeff's generic replicated `Animation`
tracks using Roblox asset metadata: `129784271201071` is `LungeHold-jeff`, and
`132817836308238` is `Attack-jeff`. Both IDs now trigger attack detection.
One automatic attempt at 11.38 studs reached the native dagger client in about
0.07 ms; the result arrived about 855 ms later as `false, 60`. Separate manual
attempts returned `false, 60` and `true, 90`. This verifies automatic activation,
not a successful automatic parry. Facing, hit timing and an unconnected swing
remain possible explanations for the failed result. A compact record is saved
in `scripts/fixtures/parry_2026_10_18.json`. The temporary round logger was stopped
when the player left the survivor team.

The October 18 resource audit scoped spear animation listeners to the current
character, releases hold-stop listeners after each charge, and cancels the map
resync worker on destruction. The FOV frame updater runs only while needed;
unchanged state updates no longer restart feature/mode tweens. The preview
allocates at most 54 visible arc segments instead of 160, while retaining the
full 160-step collision prediction and the same displayed curve.

`scripts/test_gui_resources.luau` checks 25 isolated UI reloads for stable object
and listener counts. `scripts/test_logic_resources.luau` checks 15 logic
start/destroy cycles, feature toggles, and worker/listener cleanup. The fake-camera
lifecycle test also exercises 40 charges/releases and 20 respawns. These checks
cover resource lifetimes and repeated work; they do not establish FPS or memory
usage on every device during a long game session.

A later October 18 live capture observed `82666958311998` while Jeff's `Frenzy`
attribute was true. Roblox asset metadata identifies it as `AttackFrenzy-m`;
that generic replicated `Animation` track is now recognized too. During the same
round, an automatic regular Jeff parry at 12.12 studs returned `true, 90`, and the
killer played its parried animation. The native call followed the cue by about
0.10 ms; the result arrived about 867 ms later. This confirms one successful
regular automatic parry; it does not prove success against the Frenzy move.
The compact capture is `scripts/fixtures/jeff_frenzy_2026_10_18.json`.

That round capture ended at Intermission after about 417 seconds. It recorded
nine Frenzy swings, all outside 15 studs (nearest 36.09), and two automatic
regular attempts: one successful and one unsuccessful. In the unsuccessful
attempt, Jeff faced away and moved from 6.36 studs at the cue to 18.64 studs
when the swing started. At the time, the trigger used an attack cue within 15 studs;
there is no closing-distance requirement.

Spear aim now keeps a short, bounded movement history (at most 10 samples).
Its horizontal lead follows a roughly 0.1-second position baseline and reduces
commitment when recent movement reverses or doubles back. The two horizontal
axes are evaluated separately, so lateral zigzags do not suppress steady forward
travel. A stopped target loses its old lead over the short measurement window; tight
circles and tiny replication jitter receive less lead. Facing changes alone do
not imply movement. Steady movement regains full lead, and teleports or stale
samples reset the history. Brief gaps between replication packets do not reset
the history or flip its last movement direction. The ballistic solver and arc physics are unchanged.
Tests cover these traces at 30, 60, and 144 FPS; this is a conservative prediction
of erratic movement, not knowledge of the target's next direction change.

A subsequent Veil melee capture activated the native dagger at 12.87 studs and
60 health, returning `true, 90` about 848 ms later. The earlier reported miss was
not recorded, so this later success does not explain it. The capture is saved in
`scripts/fixtures/veil_parry_2026_10_18.json`. Blocked-cue diagnostics now update
even after an earlier success and report cooldown/resolving/silenced states
without repeatedly invoking native readiness checks.

Attack-ID coverage now includes the Stalker, Killer/Jeff, Hidden, Abysswalker,
Veil, Slasher/Jason, Masked/Jacket, and a provisional SCP-labelled Cure pair.
The bounded hold lifetime follows the playing animation; ordinary swings still
expire after 0.8 seconds. Added special cues include Abyss M2, Hidden M2, and
Masked's snake/Tony attacks alongside Jeff Frenzy. Alex rev-up/run are excluded.
Roblox asset names and creator were checked on October 18; the asset record and
attribution limits are in `scripts/fixtures/killer_attack_assets_2026_10_18.json`.
These are detection candidates, not successful-parry evidence for every killer.
The range is now 13 studs with no closing-distance condition. Nearby observations
and `lastDamage` retain bounded evidence through respawns for missed-hit reports.
