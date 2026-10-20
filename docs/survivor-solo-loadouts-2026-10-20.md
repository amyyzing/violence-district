# Survivor solo queue loadout comparison — 2026-10-20

Scope: strongest overall solo queue setup, using fully upgraded perks. The live
ReplicatedStorage description catalog contains 38 survivor perks and 11 tools:
8,436 perk triples and 92,796 perk/tool combinations. The accompanying script
enumerates every combination and flags selected interaction costs. It does not
simulate matches, score win rates, or prove a unique optimum. Recommendations
below are judgments about the mechanics and solo reliability.

## Recommended default

**Ambitious Medic + Quick Recovery + Time To Grow Up, with Holy Water.**

- Ambitious Medic provides 2 healing charges per Great check while injured and
  increases default skill-check trigger chance by 40%. This lets objective work
  contribute toward recovery without first finding a teammate. Charges are not
  assumed to be percentage points; a full-heal check count was not established.
- Quick Recovery provides 40% movement speed for 3 seconds after a fast or medium
  window vault, with 50 seconds of Winded at tier three. Its value depends on
  reaching a usable window; it is less dependable in an open dead zone.
- Time To Grow Up extends the post-hit speed boost by 3 seconds. Its description
  has no Winded restriction, so it covers a different trigger from Quick Recovery.
  Simultaneous speed bonuses are not assumed to add together.
- Holy Water creates an 8-stud area for 10 seconds, ramping the killer's slow by
  6% every 0.5 seconds to 18%, on a 70-second cooldown. Route it through a doorway
  or loop; an area the killer can avoid provides little value. It does not require
  the dagger's precise 0.8-second timing window.

This spends the perk slots on sustained health and escaping chases rather than
small repair gains. Avoiding another down or a teammate-dependent rescue is the
main reason to prefer it for overall solo queue.

## Alternatives worth keeping

| Preference | Change | Tradeoff |
| --- | --- | --- |
| Repair-focused solo | Replace Time To Grow Up with Flawless Execution | Faster repairs after consecutive Great checks, less distance after getting hit. |
| Consistent parry timing | Replace Holy Water with Parrying Dagger | 4-second stun on success, but only a 0.8-second parry window; 90-second success / 60-second failure cooldown. Auto-parry success is not assumed. |
| Need guaranteed healing uses without Great checks | Replace Holy Water with Bandage | Two health-state heals, each taking 24 seconds; finite uses and some overlap with Ambitious Medic. |
| Trouble locating escape routes | Replace Time To Grow Up with Eyes of Heaven | Window/pallet information supports Quick Recovery, at the cost of the post-hit extension. |

## Important comparison results

- Heads Up, Quick Recovery, Perfect Landing, and Great Collapse all apply Winded
  and cannot activate while Winded. 2,288 loadouts contain two or more of them.
  They compete for availability rather than providing independent escape boosts.
- High Karma needs a rescue to arm its self-unhook. After use, its tier-three
  Anti-Heal lasts 60 seconds, temporarily working against self-healing options.
  Iron Tranquility + High Karma + Heads Up remains a stealth/rescue-oriented
  alternative, but has less repeatable independent sustain than the default.
- No Pain No Gain's permanent injury undermines health-restoration choices;
  this is an interaction cost, not a claim that the game prevents equipping them.
- Perfectionist Planning trades flexibility for bonuses on three generators;
  Partners In Crime and Group Project depend on other survivors for their repair
  benefits. Those conditions weaken their fit for independent solo play.
- Killer-information tools overlap with this user's existing player Highlights.
  That does not make window/pallet information redundant.
- Twist of Fate has a 40% misfire chance costing a health state, a poor fit for a
  recommendation prioritizing consistency.

## Live repair observation

A bounded attribute observer recorded the local character's repairboost changing
from 1 to 1.05 with flawless_execution_streak=1, remaining 1.05 at streak=2, then
changing to 1.0815000000000001 at streak=3. This is consistent with multiplicative
5% and 3% bonuses: 1.05 * 1.03 = 1.0815, or 8.15% faster repair rate. Attribute
events in the same update were paired; these are not separate repair trials.

At a continuously maintained multiplier, fixed-work time would fall by about
7.54%, not 8.15%. Actual generator completion gains depend on ramp-up, check
bonuses, interruptions, and other effects. No current baseline completion time,
full-heal Great-check count, or comparative win rate was established here. The
temporary observer was stopped and disconnected after collection.

Source: `scripts/fixtures/survivor_loadout_catalog_2026_10_20.json`, captured from
live perk/tool descriptions. Descriptions do not establish every server-side
interaction; the repair attribute observation is the narrower runtime check.
