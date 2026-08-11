# Telemetry-driven playtesting

Paper Flight emits one stable analytics contract through
`lib/services/analytics_service.dart`. Custom gameplay events include the
`balance_version` parameter from `GameConfig.balanceVersion`. Increment that
value whenever any progression, hazard, reward, wind, power-up, or ad tuning is
changed.

## Core dashboard events

| Question | Events / fields |
|---|---|
| Are players returning? | Firebase app-open cohorts + `app_session_started`, `app_session_ended.duration_seconds` |
| Do players reach a run? | `mode_selected` → `run_started` funnel |
| Where do runs end? | `run_completed.crash_cause`, `run_abandoned.reason`, grouped by `mode` |
| Is difficulty fair? | `distance_meters`, `duration_seconds`, `final_biome`, `max_combo`, `near_misses` |
| Are trials readable? | `trial_selected` → `trial_completed`, including `completed`, `failure_reason`, `stars`, and course coins |
| Can a seeded layout be reconstructed? | `run_started.run_seed` plus `rng_algorithm_version`, `balance_version`, and `run_completed.replay_fingerprint` |
| Are rewards paced well? | `economy_transaction`, grouped by `currency`, `direction`, and `reason` |
| Are ads healthy? | `ad_requested` → `ad_impression` → `ad_outcome` / `ad_reward_earned` |
| Do low-end devices hold frame budget? | `game_frame_performance`: average/p95 build, raster and total frame time, slow/frozen frames |
| Did a long run keep system health bounded? | `game_runtime_diagnostics`: trace count, active entities, pool creation/discard/rejection/peak counters |
| Does onboarding help? | `onboarding_action` by `surface`, `action`, `page`, and `mode` |

## Recommended tuning loop

1. Ship the current baseline without changing several knobs at once.
2. Segment by `balance_version`, mode, device class, control scheme, and
   lifetime-run band.
3. Establish sample-size and guardrail targets before changing a value.
4. Change one related family at a time (for example obstacle interval + minimum
   gap), increment `balanceVersion`, and compare cohorts.
5. Watch retention and ad opt-in guardrails as well as score/death metrics.
6. Keep a rollback profile for every released balance version.

Suggested first guardrails:

- first-run tutorial completion and first-flight conversion;
- median first-run death distance and deaths under 15 seconds;
- D1/D7 retention and median foreground session duration;
- per-biome crash cause distribution;
- trial completion and 1/2/3-star distribution per course;
- coins sourced vs sunk per active player;
- rewarded request-to-reward rate and interstitials per session;
- p95 total frame time and >100 ms frozen-frame count on low-memory Android.

## Device validation

Frame telemetry is a release signal, not a replacement for profiling. Test a
physical low-end Android matrix in Flutter profile mode and capture DevTools CPU,
memory, raster, shader, and network traces. Include at least:

- a 2–3 GB RAM / 60 Hz device;
- a thermally throttled 4 GB mid-range device;
- a high-refresh device to catch accidental 90/120 Hz rebuild work;
- gesture-navigation and display-cutout variants;
- text scaling at 1.0, 1.5, and 2.0 and both supported locales.
