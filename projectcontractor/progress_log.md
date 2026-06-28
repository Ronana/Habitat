# Project Contractor — Progress Log

---

## 2026-06-26 — Phase 0 Complete

### Completed this session
- Created full folder structure per Build Brief spec (all 10 leaf folders confirmed)
- Created placeholder brand assets in `assets/ui_theme/`:
  - `logo_placeholder.png` (256×128, navy)
  - `app_icon_placeholder.png` (256×256, gold)
  - `shop_chest_icon_placeholder.png` (128×128, green)
  - All three imported by Godot (`.import` sidecar files present)
- Created `scripts/autoload/GameState.gd` — stub (`extends Node`, comment only)
- Configured `project.godot`:
  - Portrait orientation (`window/handheld/orientation="portrait"`)
  - 720×1280 viewport
  - Mobile renderer (`renderer/rendering_method="mobile"`, `config/features` includes `"Mobile"`)
  - `GameState` registered as autoload singleton
  - `scenes/main/Main.tscn` set as main scene (Node2D root, no children)
- Connected Godot project folder to Cowork file access (`D:\Godot\Projects\projectcontractor`)

### Phase 0 checkpoint status
✅ Project boots in Godot editor with correct mobile/portrait settings  
✅ GameState autoload registered  
✅ Placeholder assets imported  
⏳ Real device/export check deferred to Phase 6 (no Android template yet)

### Next step
~~Awaiting Phase 0 confirmation~~ — confirmed. Phase 1 complete (see below).

---

## 2026-06-26 — Phase 1 Complete

### Completed this session
- Defined 4 Resource classes in `scripts/data/`:
  - `MaterialResource` — id, display_name, icon, base_value
  - `BuildStageResource` — id, display_name, required_materials (Dictionary), stage_order
  - `BuildingTierResource` — id, display_name, stages (Array[BuildStageResource]), build_power_required, unlock_condition
  - `CrewMemberResource` — id, display_name, base_speed_bonus, hire_cost, level, material_type
- Implemented full `GameState` autoload: cash, gems, materials, crew, current_building, skyline, last_saved_timestamp
- Implemented `SaveManager` autoload: save/load to `user://save.json`, 30s autosave, save on pause/quit
- Implemented `OfflineProgressCalculator` autoload: credits idle material gains on launch (capped 12h), emits `offline_gains_applied` signal
- Registered all three autoloads in `project.godot` in correct dependency order (GameState → SaveManager → OfflineProgressCalculator)

### Phase 1 checkpoint — how to verify
1. Open the project in Godot and hit **Play (F5)** — no errors in the Output panel
2. Stop the game, wait 10+ seconds, run again
3. The Output panel should print: `OfflineProgressCalculator: +{"timber": N} after Xs offline`
4. The `user://save.json` file should appear in Godot's user data folder

### Next step
~~Awaiting user confirmation~~ — confirmed. Phase 2 complete (see below).

---

## 2026-06-26 — Phase 2 Complete

### Completed this session
- Created `scripts/data/BuildDatabase.gd` autoload: defines Garden Shed (4 stages) inline as BuildingTierResource/BuildStageResource instances. Registered between GameState and SaveManager in project.godot.
- Updated `scripts/autoload/OfflineProgressCalculator.gd`: stores offline gains in `_last_gains`/`_last_elapsed` instead of emitting signal immediately in `_ready()` (timing fix). Added `get_offline_summary()` and `clear_offline_summary()` for polling from Main.
- Wrote `scenes/main/Main.gd`: full Phase 2 scene built entirely in code.
  - Top HUD bar: Cash, Gems, Timber, Stone counts (CanvasLayer)
  - Build site: ground ColorRect + building ColorRect (lerps brown -> grey as stages complete)
  - Two tap Buttons: Timber Pile and Stone Pile, +5 per tap
  - Stage progression: auto-completes when materials >= required; consumes materials, awards cash, advances stage_index
  - Building complete: appends tier_id to skyline, +100 cash, resets to stage 0
  - Tween pop on stage/building complete; fade feedback label on every tap
  - Bottom stage panel: per-material have/need counts with tick marks
  - Offline summary polled from OfflineProgressCalculator on _ready()
- Updated `scenes/main/Main.tscn`: attached Main.gd via ext_resource reference.
- Autoload order: GameState -> BuildDatabase -> SaveManager -> OfflineProgressCalculator

### Garden Shed stage data
Stage 1: Site Clearance (timber 20) | Stage 2: Foundations (stone 30, timber 10)
Stage 3: Wall Framing (timber 40, stone 10) | Stage 4: Roof & Finish (timber 20, stone 15)

### Phase 2 checkpoint — how to verify
1. Play (F5) — no errors in Output
2. Tap Timber Pile / Stone Pile — HUD increments by 5 per tap
3. Gather 20 timber — stage auto-advances, building rect lightens, feedback appears
4. Complete all 4 stages — "Building complete!" message, skyline count +1, resets to stage 1
5. Stop + restart — material counts and stage index restored from save

### Next step
~~Awaiting user confirmation~~ — confirmed. Phase 3 complete (see below).

---

## 2026-06-26 — Phase 3 Complete

### Completed this session
- Added crew templates to `scripts/data/BuildDatabase.gd`:
  - Old Bob — Timber, hire 40 cash, 0.5/s per level
  - Granite Pete — Stone, hire 50 cash, 0.5/s per level
  - Nimble Nick — Timber (premium), hire 90 cash, 1.0/s per level
  - New `get_hireable_crew()` method returns the template list
- Replaced Phase 1 stub in `OfflineProgressCalculator._get_idle_rates()` with real crew-based rate calculation (empty dict if no crew hired)
- Rewrote `scenes/main/Main.gd` with full Phase 3 crew system:
  - `_process()` tick: accumulates fractional materials from crew rates each frame
  - CREW button (y=705) toggles full-screen crew overlay panel
  - Crew panel: 3 cards (one per template) showing name, material type, rate, level
  - Hire button (if not hired, disabled if insufficient cash)
  - Level-up button (if hired): cost = hire_cost * current_level; updates rate label
  - `_update_crew_panel()` refreshes all card state after any hire/level-up
  - Crew panel auto-closes when user taps X or CREW button again

### Crew rates reference
| Crew | Material | Base rate | Level 2 | Level 3 |
|------|----------|-----------|---------|---------|
| Old Bob | Timber | 0.5/s | 1.0/s | 1.5/s |
| Granite Pete | Stone | 0.5/s | 1.0/s | 1.5/s |
| Nimble Nick | Timber | 1.0/s | 2.0/s | 3.0/s |

Level-up cost: hire_cost * current_level (Bob L1->L2: 40 cash, L2->L3: 80 cash, etc.)

### Phase 3 checkpoint — how to verify
1. Play (F5), tap CREW button — panel opens with 3 crew cards
2. Hire Old Bob (40 cash) — hire button hides, level-up button appears, HUD cash drops by 40
3. Close crew panel — building rect should slowly lighten on its own as Bob gathers timber
4. Leave idle 10+ minutes (or adjust system clock) — on relaunch, offline gains should match Bob's rate × elapsed time
5. Level up Bob in crew panel — rate label updates, subsequent gains increase

### Next step
~~Awaiting user confirmation~~ -- confirmed. Phase 4 complete (see below).

---

## 2026-06-26 -- Phase 4 Complete

### Completed this session
- Added `get_build_power()` to `GameState.gd`: sum of hired crew levels x 1.0 (linear MVP placeholder per Build Brief; multiplier field noted for future exponential tuning per GDD Section 9)
- Added to `BuildDatabase.gd`:
  - `TIER_ORDER = ["shed", "single_house", "two_story_house"]`
  - `get_next_tier_id()` -- returns next tier id or "" if at max
  - Tier 2: **Single-Storey House** (build_power_required=3, 5 stages)
  - Tier 3: **Two-Storey House** (build_power_required=8, 5 stages)
- Rewrote `scenes/main/Main.gd` with full Phase 4 additions:
  - `_complete_building()` now checks next tier BP gate; advances or shows wall panel
  - **Wall panel** (CanvasLayer 25): shown when BP < required; displays tier name, BP needed vs current; "Keep Building" dismisses, "Open Crew" opens crew panel
  - **Skyline panel** (CanvasLayer 20): shows every completed building as a coloured swatch + name row; "nothing built yet" state handled; opened via SKYLINE button
  - CREW and SKYLINE buttons repositioned side-by-side (y=712)
  - `_update_building_visual()` now uses `_tier_colour()` as the base colour per tier, lerped to grey as stages complete (visual distinction between Shed/House/Two-Storey)

### Tier data summary
| Tier | BP Required | Stages | Total Timber | Total Stone |
|------|-------------|--------|-------------|-------------|
| Shed | 0 | 4 | 90 | 55 |
| Single-Storey House | 3 | 5 | 175 | 130 |
| Two-Storey House | 8 | 5 | 280 | 135 |

### Phase 4 checkpoint -- how to verify
1. Complete the Shed with BP < 3 -- wall panel should appear ("Build Power Too Low")
2. Hire/level crew to reach BP 3 -- complete another Shed -- should advance to Single-Storey House
3. Complete Single-Storey House with BP < 8 -- wall panel again
4. Reach BP 8 via crew upgrades -- break through to Two-Storey House
5. Open SKYLINE button -- shows all completed buildings as coloured rows
6. Complete Two-Storey House -- loops on it (max tier for MVP); skyline grows

### Next step
~~Awaiting user confirmation~~ -- confirmed. Phase 5 complete (see below).

---

## 2026-06-26 -- Phase 5 Complete

### Completed this session
- **Gem earning wired**: +1 Gem per stage completion, +5 Gems on building completion (placeholder rates, easy to tune)
- **Shop panel added** to `Main.gd` (CanvasLayer 20):
  - Accessible only via SHOP button tap -- never auto-opened
  - Gems balance display at top
  - Policy notice: "Gems are earned through play. Every item here is optional and never required to progress."
  - Item: **Instant Stage Skip** (10 Gems) -- advances stage_index without consuming materials; disabled if < 10 Gems or no stage in progress
  - Rewarded-ad placeholder card (non-functional, labelled "always player-initiated, never forced") for future integration reference
  - Skip-to-building-complete closes shop before showing wall panel (avoids z-order conflict)
- **CREW / SHOP / SKYLINE buttons** repositioned as three equal buttons centred across 720px
- All panel close logic updated so each button closes the other panels

### Policy compliance audit (release-blocking check per Build Brief)

Reviewed every `.visible = true` call site in Main.gd:

| What opens | Trigger | Contains purchase prompt? | Verdict |
|---|---|---|---|
| Crew panel | Player taps CREW button | No | PASS |
| Shop panel | Player taps SHOP button | Yes (inside Shop only) | PASS |
| Skyline panel | Player taps SKYLINE button | No | PASS |
| Wall panel | Building completed + BP too low | No (gameplay message only) | PASS |
| Crew panel (from wall) | Player taps "Open Crew" on wall | No | PASS |
| Feedback label flash | Tap / stage complete / offline | No | PASS (non-blocking) |

No forced interstitials. No purchase prompts outside Shop. No overlays appear unprompted from timers or signals. The wall panel triggers from game progress (building complete) but contains zero monetisation content -- it is the intended progression wall, not an ad.

### Phase 5 checkpoint -- how to verify
1. Play -- SHOP button opens Shop panel; closing returns cleanly to gameplay
2. Complete stages -- Gems increment (+1/stage, +5/building)
3. Accumulate 10 Gems -- "Buy (10 Gems)" button enables; pressing it advances current stage without consuming materials
4. Confirm no purchase popup ever appears without tapping SHOP first
5. Confirm wall panel (when it appears) has no "buy" language -- only "Upgrade your Crew"

### Next step
~~Awaiting user confirmation~~ -- confirmed. Phase 6 in progress (see below).

---

## 2026-06-26 -- Phase 6 In Progress

### Completed this session
- **ModernHouseA.png atlas wired into build display** (`scenes/main/Main.gd`):
  - Added `Sprite2D` (`_building_sprite`) at centre (360, 320), scale 1.2 — fills the build area from HUD to tap buttons
  - Added `_get_stage_texture(tier_id, stage_idx)` and `_atlas_region(col, row)` helpers
  - `ModernHouseA.png` grid: 5×2, 281×384px per cell (last column 284px); row 0 = Single-Storey House stages 0–4, row 1 = Two-Storey House stages 0–4
  - `_update_building_visual()` shows Sprite2D + AtlasTexture for house tiers, ColorRect for shed (no art yet)
  - `_pop_building()` tween targets the visible node with correct base scale per node type
  - Atlas texture loaded once on first use (`_house_sheet_tex` cache); `filter_clip = true` prevents cell bleed

### What's still needed for Phase 6

**Art still required from user:**
- Garden Shed stages (4 images) -- keeps ColorRect placeholder until provided
- Two-Storey House art is covered by ModernHouseA.png row 1

**Remaining Phase 6 tasks:**
- Logo / branding on main screen (MainLogoWText.png, BannerLogo.png)
- HUD icon art (ShopIcon.png and Settings Icon.png wired in)
- Placeholder SFX (tap feedback, stage-complete, building-complete) via programmatic AudioStreamWAV tones
- Android export setup + real device smoke-test (user performs)
- Force-quit stress test (user performs)
- MVP Definition of Done checkpoint (full loop: fresh install → Shed → wall → crew → Tier 2 → Skyline → close/reopen → offline gains → Shop policy check)

- **Crew rate rebalance**: Granite Pete raised to 1.0/s stone, hire cost 75 (was 0.5/s, 50). All-crew ratio now 1.5:1 timber:stone, matching material demand across all tiers.
- **Branding wired in**:
  - `BannerLogo.png` (211×54) displayed in left 260px of the HUD bar (STRETCH_KEEP_ASPECT_CENTERED). Stats row shifted to occupy the remaining 460px.
  - `MainLogoWText.png` (1600×409) shown on a 2.5s splash screen (CanvasLayer 30) on every launch — navy background, logo centred, tap anywhere to skip, fades out automatically.
- **Pre-ship art blocker noted**: Stage-number labels baked into `ModernHouseA.png` cells ("Stage 7" etc.) are visible simultaneously with the game's own "Stage 2/5" UI text. Clean asset versions without baked text are required before MVP sign-off.

### What's still needed for Phase 6
- Garden Shed stage art (4 images) — still awaiting from user
- Placeholder SFX (tap feedback, stage-complete, building-complete) via programmatic AudioStreamWAV tones
- Android export setup + real device smoke-test (user performs)
- Force-quit stress test (user performs)
- MVP Definition of Done checkpoint

- **UI/UX overhaul complete** — `scenes/main/Main.gd` fully rewritten with IOM-inspired dark theme:
  - Dark colour palette (`C_BG`, `C_PANEL`, `C_CARD`, `C_BORDER`, per-resource accent colours)
  - HUD: colour-coded stat chips (gold/cyan/amber/grey) with BannerLogo retained left
  - Build site: dark background, tap buttons styled as accent-bordered coloured cards
  - Stage info panel: two material-requirement progress bars (Timber + Stone) with live fill
  - Bottom tab bar (CanvasLayer 50 — always on top over panels): CREW / SHOP / SKYLINE with active-tab indicator bar + colour highlight
  - Crew panel: IOM-style cards — avatar initial, material accent border, rate label, level label, green Hire / gold Upgrade buttons, level-progress bar at card bottom
  - Wall panel: dark red accent/border, danger title in red
  - Skyline panel: gold header border, ScrollContainer so list can grow
  - Shop panel: cyan header border, styled item card, all policy text retained
  - All game logic (tap, crew tick, stage/tier advancement, shop, offline gains) unchanged

### What's still needed for Phase 6
- Garden Shed stage art (4 images) — still awaiting from user
- Placeholder SFX (tap feedback, stage-complete, building-complete) via programmatic AudioStreamWAV tones
- Android export setup + real device smoke-test (user performs)
- Force-quit stress test (user performs)
- MVP Definition of Done checkpoint

### Next step
Test the UI overhaul in Godot (F5). Check for any script errors, then confirm visuals look correct before proceeding.
