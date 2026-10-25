# Normal skill checks and current killer melee cues

Logic/UI version: 106.

Normal previously submitted upon entering 102–116 degrees, which the inspected
native handlers score as great/perfect. It now waits until the relative needle
angle is strictly greater than 116 and at most 159. It does not use a perfect
fallback when Normal is selected. Perfect keeps its existing great target and
normal fallback. A frame skipping the entire selected window can still miss.

The active Butcher's Animations LocalScript declares third-person lungehold
127417297154354 and attack 83333467665074. Those are explicit fallback IDs.
Its trap placement, chain throw/pull, chain idle and chain latch tracks are not
treated as ordinary melee. Evidence is recorded in the accompanying fixture.

Other killers' animation controllers are attached to their live characters;
not every current controller is present simultaneously in replicated storage.
Auto parry now reads the killer character's Animations LocalScript once during
setup and extracts only literal third-person lungehold, attack and attackfr IDs.
No returned source is executed. The lookup is cached with weak script keys,
does not run during attack/range processing, and does not install idle polling.
Disabling/changing characters discards stale asynchronous results. Existing
verified fallback IDs remain when decompilation is unavailable. Computed IDs or
controllers with a different shape require separate inspection; no unknown
animation is guessed to be an attack.

Validation: offline checks passed 133 auto-parry assertions, including fresh
controller discovery, Butcher assets, one read across combat/role changes, and
exclusion of viewmodel/stun assets. Roblox fixtures passed 134 auto-parry
assertions (including native callback discovery), 420 resource-lifetime
assertions and the skill-check boundary/tween/callback suite. Normal tests cover
102/108/116 rejection, 117 and 159 acceptance, and a skip beyond 159. These are
isolated checks, not proof of a successful parry against every killer in combat.

Live installation readback confirmed version 106, a bound native dagger client,
and exactly one successful source read/resolution for the active Butcher. No
idle range monitor was installed. Existing feature preferences and selected
skill-check mode were preserved. This confirms discovery and binding, not a
successful parry against every killer.
