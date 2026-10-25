# Halloween update audit — October 24, 2026

Source: the supplied Butcher/Halloween notes and the connected live game's
Explorer/client scripts. Patch notes are context; the currently loaded source
determines the math changes. In particular, notes list 0.2 seconds minimum charge
and 17 ms delay, while the current shared module has 0.3 seconds and 12 ms.

## Fixed in logic 105

- Veil: shared `Modules.Killers.Veil.SpearMath` has Speed=180, Gravity=(0,-98.1,0),
  SpawnOffset=3, MinimumChargeTime=0.3, ThrowStartDelay=0.012, MaxLife=4.
  `ProjectileVisualsClient.predict` uses camera origin + direction*3 and
  `SpearMath.power(held)`. The release handler waits for minimum charge. Preview
  speed now reflects this wait. A fully charged ordinary shot remains at 180
  even when piercing is unavailable. The two-second piercing gate remains.
- Preview and interception use analytic flight; the old weighted frame-step
  correction and its idle Heartbeat sampler were removed. The intercept solves
  travel distance `speed*time + spawnOffset` from the camera so turning the aim
  does not keep an origin based on the previous look direction.
- Current Veil animation source: melee hold 84926129581106, swing 81963230963908;
  charge/start/loops 77303734522729, 87436543050891, 79809716042968,
  122765810542358; throws 101443662521580 and 127622545856523. The generic
  replicated swing track was also observed during the round. Old IDs remain for
  retained animation variants rather than guessing that every unknown cue is an attack.
- Native generator/healing `InputBegan` handlers call
  `KeybindsConfig.matches("skillcheck", input)`. Discovery accepts that signature
  and supplies the current `kb_skillcheck` binding, including mouse buttons.
  Spear input follows `kb_basicattack` / `pad_basicattack` defaults and attributes.
- `ParryClient` now receives success, cooldown, permanent, reset, character.
  Diagnostics ignore foreign-character and reset messages instead of consuming
  a pending result. The game client remains responsible for cooldown/readiness.

## Checked without changing behavior

- Current survivor scripts retain the names Skillcheck-gen / Skillcheck-player.
  Ordinary great/normal angle windows remain 102–116 and over 116 through 159.
  Native handlers now carry their own current result/sequence arguments; no
  results or timestamps are forged by the helper.
- Live generator models still have `RepairProgress` and `HitBox`. Existing
  proportional labels were present on incomplete generators in the current map.
- The equipped dagger remains a character Model named `Parrying Dagger`.
  The current native client was discoverable from its result-event callback.
- Current spear world casting has its own transparency/tag rules. The user's
  requested display filter still ignores fully transparent/non-colliding parts;
  this is intentionally not a promise to mirror every server collision surface.

## Validation and limits

- 60 pure position samples returned by live SpearMath are retained in
  `scripts/fixtures/veil_halloween_2026_10_24.luau`. Offline checks compare the
  preview with those values and an independent midpoint flight integrator.
- Roblox isolated fixtures passed: 2,241 projectile assertions against the live
  math module/collision fixtures, 160 fake-camera lifecycle assertions, 420
  resource-lifetime assertions, and the native skill-check callback/tween suite,
  including remapped keyboard/mouse input and skipping visible trap prompts.
- These tests do not establish actual throw impact accuracy, successful parries,
  or server acceptance of every automated skill check in this game update.
- Butcher trap prompts add `TrapGoal` and `TrapPerfect` to the shared Check frame.
  Their timing is separate; automation leaves a visible trap goal alone. Butcher
  attack/chain cues still require inspection during an active Butcher round.
- New survivor bots and all other killers' replacement/skin animations were not
  completely covered. No unknown ability cue is blindly treated as a melee attack.
- The October 20 loadout report is historical: Time To Grow Up now conflicts
  with other Winded perks, and Quick Recovery was changed. A new strongest-build
  conclusion requires comparing the refreshed perk/tool catalog.

Version 105 was loaded into the connected client. Readback confirmed its GUI,
retained feature preferences, bound native dagger client, and both cached native
skill-check callbacks belonging to the current character. No successful automatic
parry or actual Veil impact was established by this readback.
