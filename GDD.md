# Driftpaper / Paper Flight — Game Design Document

*(working title — alternatives: **Windborne**, **Paper Sky**, **Glide & Glory**, **Skyfold**)*

**One-line pitch:** A paper plane rides gusts of wind through an ever-changing sky — one tap, infinite falls.

| | |
|---|---|
| **Genre** | Endless arcade flyer / "one-more-try" casual |
| **Platform** | Mobile (iOS + Android), Portrait |
| **Engine** | Flutter + Flame |
| **Monetization** | F2P — Ads (rewarded + interstitial) + IAP |
| **Target session** | 45–90 seconds per run |

---

## Implementation status (MVP)

| # | Feature | Status |
|---|---------|--------|
| 1 | Hold-to-lift / release-to-glide core physics | ✅ |
| 2 | Tilt-to-steer left/right (+ touch-zone alt) | ✅ |
| 3 | City Rooftops biome + 5 obstacle types | ✅ (+ full biome progression scaffold) |
| 4 | Coins + score/combo + near-miss | ✅ |
| 5 | Shield + Magnet (+ Turbo, Slow-Mo, Second Wind) | ✅ |
| 6 | Game over + rewarded-ad revive | ✅ |
| 7 | 3 unlockable plane skins (coin hangar) | ✅ |
| 8 | Remove Ads IAP + rewarded/interstitial ads | ✅ |
| 9 | Local high score leaderboard | ✅ |

See full design below for systems deferred to post-launch (season pass, live-ops, global leaderboards, trails).

---

## 1. Core Fantasy

You're a paper plane thrown out a window, riding wind currents as far as you can before gravity, a hawk, or a power line ends the dream. Every run is short, every death feels "one more try"-close, and the sky itself becomes more alive (and dangerous) the farther you go.

## 2. Controls

| Input | Effect |
|-------|--------|
| **Hold anywhere** | Plane angles up, applies lift, climbs |
| **Release** | Plane noses down, glides, gravity takes over |
| **Tilt phone L/R** | Banks left/right to dodge and steer into coin lanes |
| **Double-tap** | Short speed-burst "paper snap" — limited charges, refills over distance |
| **Alt: touch zones** | On-screen left/right halves for tilt-averse / accessibility |

Settings include tilt sensitivity slider + control scheme toggle. Tilt auto-calibrates to posture each run.

### Camera & World Model

This is a **vertical scroller**:

- Plane moves freely on both axes within screen bounds (hold → Y, tilt → X).
- World scrolls **downward** at steadily increasing base speed.
- Distance/score is driven by scroll speed × time — **not** plane on-screen position.
- Static camera/viewport — no camera-follow logic.

## 3. Core Flight Mechanics

- Hold lifts plane up on screen; release lets gravity pull down.
- **Fail states:** falling off bottom edge, or hitting any obstacle.
- No hard ceiling death — over-climbing punished by spawn proximity / upper hazards.
- Momentum-based turning: diving fast = sharp turns; climbing slow = gentle drift.
- Soft difficulty via scroll speed ramp.

## 4. World & Wind System

Screen width divided into **4 wind column-lanes**, each with independent crosswind (left / right / calm / turbulent / thermal). Gusts shove sideways; thermals grant free altitude; turbulence reduces control precision.

**Biome progression by distance:**

1. Backyard Morning  
2. City Rooftops  
3. Storm Front  
4. Mountain Pass  
5. Night Sky  
6. Edge of Atmosphere  

## 5–10. Obstacles, Collectibles, Power-ups, Meta, Retention, Monetization

Implemented per original GDD. Key monetization rules:

1. Never gate core gameplay behind paywall  
2. Ads opt-in (rewarded) except capped interstitials at natural breaks  
3. First 3 runs ad-free honeymoon  
4. Track ad frequency + rewarded completion as KPIs  

## 11. Screen Flow

```
[Splash] → [Main Menu] ──┬─→ [Hangar] → back
                         ├─→ [Shop] → back
                         ├─→ [Daily Challenges] → back
                         ├─→ [Settings] → back
                         └─→ [PLAY] → [Gameplay] → [Game Over]
                                                   ├─→ Watch Ad to Revive
                                                   ├─→ 2× Coins
                                                   ├─→ Retry
                                                   └─→ Menu
```

Tap-to-play under **2 taps** from app open.

## 13. Technical Notes

- `FlameGame` + static `CameraComponent.withFixedResolution`
- Object pools for obstacles / coins / power-ups
- Wind via FBM value noise (`lib/core/utils/noise.dart`)
- Tilt via `sensors_plus` + low-pass filter
- Ads: `google_mobile_ads` · IAP: `in_app_purchase`
- Persistence: Hive (`SaveData`) + settings box
- State: Riverpod outside the game loop; Flame components inside

## 15. Key Differentiators

- Two-axis control (hold + tilt)  
- Wind as a systemic mechanic  
- Near-miss / combo scoring  
- Cosmetic-leaning meta-progression  
