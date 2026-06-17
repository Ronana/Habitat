# Habitat — Feature Roadmap (Viva Piñata Analysis)

_Researched June 2026 from vivapinata.fandom.com. Every VP mechanic below is mapped
to what Habitat already has, then re-imagined in Habitat's own style._

---

## What VP Does That Makes It Special

Before the list: the _feel_ of VP comes from three interlocking loops:

1. **Ecosystem pull** — each new species you attract unlocks conditions for the next one (food chain).
2. **Moment-to-moment juice** — every single action has a satisfying micro-animation or sound.
3. **Managed chaos** — the garden is alive and constantly breaking in small, fixable ways (conflicts, sickness, sour piñatas). The player is always the gardener, never just the viewer.

Habitat already nails loop 1 (attraction stages, zone unlocking) and is building loop 3 (needs system). The biggest gap right now is **loop 2** — the juice.

---

## Tier 1 — Next Up (High Impact, Low/Medium Effort)

### 1. Seed Planting Animation ⭐ (THE ONE YOU MENTIONED)
**What VP does:** When you plant a seed with the Seed Bag, the seed bounces off the
ground, pops up into the air, then plants itself with a little puff of soil.

**Habitat version:**
- When the player places a Berry Bush or any plantable item, trigger a 3-phase tween:
  1. Seed spawns at cursor, bounces down to ground (`TRANS_BOUNCE`)
  2. Hops back up slightly, rotates
  3. Plants itself — scale squish down to 0, ground puff particle burst, bush grows up from scale 0 with `TRANS_SPRING`
- Berry bushes and wildgrass seeds both get this treatment.
- **Why it matters:** This is pure juice. Zero gameplay change, massive feel upgrade.

**Files:** `tool_manager.gd` (item placement), `berry_bush.gd`

---

### 2. Egg Hatch Sequence (Micro-animation upgrade)
**What VP does:** Egg wobbles, cracks appear, baby breaks out, stretches, forms a
cocoon, adult emerges with sparkles.

**Habitat version (using what already exists):**
- Egg object spawns at shelter exit after breeding
- Phase 1 (5 s): Egg rocks side to side (tween rotation ±8°, loop 4x)
- Phase 2 (2 s): Cracks appear (shader or overlay mesh), egg shakes harder
- Phase 3: Egg scale → 0 with pop, baby roamer spawns at scale 0.1 → 0.6 with spring bounce
- Baby does a single stretch bob (head dip + body squish), then wanders
- Confetti/spore particles from garden.gd burst at hatch position
- Toast notification: "✨ A baby [species] hatched!"

**Files:** `roamer_base.gd` (`_spawn_offspring()`), `garden.gd`

---

### 3. Breeding Heart Indicator
**What VP does:** A heart floats above a piñata's head when it's ready to romance.
Hearts are cyan (inverted) when the population cap is reached.

**Habitat version:**
- When a bonded roamer's happiness ≥ 0.85 AND their mate is also bonded in the same
  shelter AND the shelter has room for offspring, a floating heart Label3D or small
  Billboard billboard pulses above their head.
- If at population cap (e.g. >12 total roamers), heart turns blue/cyan as a visual hint
  rather than a red error message.
- Already have the breeding click system — this just gives it a visible signal.

**Files:** `roamer_base.gd`, `roamer_ui.gd` (or new `needs_indicator.gd`)

---

### 4. Soured Roamers (VP's "Sour Piñatas")
**What VP does:** Sour piñatas are corrupted wild versions that wander into the garden,
attack residents, destroy plants. Taming them (hit with shovel → feed them) converts
them to a special "tamed sour" variant worth bonus coins.

**Habitat version:**
- At Warden level 40 (already in `level_unlocks`), a **Blight Roamer** can enter the
  garden every 10–20 real minutes.
- Blight Roamers: same species mesh but with a dark/desaturated shader override + red
  eye glow + dark particle trail.
- Behaviour: wanders aggressively, scares nearby residents (lowers their safety need
  sharply), eats berry bushes in one go (depletes without trigger).
- **Taming:** Player clicks Blight Roamer → popup "Offer an Elder Moss offering?
  (costs 5 Eldermoss)". Accept → Blight does a struggle animation, calms, fur
  returns to normal with a sparkle burst.
- Tamed Blight rewards: 200 XP + 50 Dewdrops + a rare "Blight Mark" trait on the
  roamer (visible as a faint dark rune on their side).
- If ignored for 3 in-game days, Blight Roamer leaves on its own.

**Files:** New `blight_roamer_manager.gd` autoload, each species script

---

### 5. Roamer Variant System (Color transforms)
**What VP does:** Feed a piñata specific items → permanent color recolor. 3 variants
per species, each worth XP.

**Habitat version:**
- Each roamer species has 2 hidden variants (total 6 new looks across 3 species).
- Feeding a specific rare item changes the roamer's shader color permanently.
  - Mossdeer + **Moonpetal Flower** → Silver/white coat
  - Mossdeer + **Crimson Berry** → Rust-orange coat
  - Stoneback + **Sunstone Shard** → Gold-veined shell
  - Stoneback + **Deep Moss** → Dark jade shell
  - GlowFox + **Starfire Seed** → Blue flame tail
  - GlowFox + **Duskbloom** → Violet/pink glow
- Transformation: feed animation → brief white flash → color shift tween (2 s) → 
  sparkle burst → milestone popup "✨ New variant discovered: Silver Mossdeer!"
- Variants are saved as a `variant_id` string on the roamer, loaded on start.
- Rare items sold by Maren at high Warden level.
- Each variant unlocks a Milestone entry worth 25 XP.

**Files:** `roamer_base.gd` (variant_id + shader swap), `maren.gd` (new shop items),
`milestone_manager.gd`

---

### 6. Species Conflict System
**What VP does:** Some species dislike others (Barkbark vs Kittyfloss). When two
conflicting species meet, they get red eyes and start a fight. Fights lower happiness.
Player must intervene (water them, fence them off, use a peacemaker species).

**Habitat version:**
- Define a conflict table in `roamer_base.gd` or a new `conflict_data.gd`:
  ```gdscript
  const CONFLICTS = {
      "Mossdeer": ["Stoneback"],   # deer spooked by stone shell retreat
      "GlowFox":  ["Stoneback"],   # fox circles stoneback aggressively
  }
  ```
- When two conflicting species come within 4 units: both enter a new `State.AGITATED`
  — they face each other, the agitated roamer's eyes flash red (shader param), and
  they emit a low growl sound.
- After 5 s of contact: brief bump animation, both lose 0.2 happiness, then move apart.
- Player resolution: watering agitated roamer (Watering Can tool) resets agitation.
  Placing a fence item between them also stops conflict.
- Adds tension and gives the player something to manage mid-session.

**Files:** `roamer_base.gd`, `player_cursor.gd` (watering interaction)

---

## Tier 2 — Next Sprint (Medium Effort, High Reward)

### 7. Visiting NPC Characters
**What VP does:** Seedos wanders in and gives you seeds. Leafos gives hints. Dastardos
comes for sick piñatas. These NPCs make the garden feel alive and visited.

**Habitat version — 3 new visitor characters:**

**Fernwick the Spriggan** (replaces Seedos concept)
- Wanders into the garden every 3–5 in-game days
- Moves slowly toward the player, stops, holds out a seed packet
- Player clicks → receives a random rare seed (new plantable type)
- Plays a little jig, leaves back over the rune boundary
- Uses a simple procedural mesh + animation (no external model needed)

**The Wayfarer** (mystery trader)
- Arrives on the eastern zone marker path
- Sells 1–3 rare items that rotate per visit (rare seeds, variant foods, accessories)
- Costs Eldermoss, not Dewdrops — making Eldermoss feel more purposeful
- Leaves after 2 in-game days if not interacted with

**The Grimshroud** (consequence character — replaces Dastardos)
- Only appears when a roamer's needs are all critical for 2+ in-game days
- Slowly stalks toward the distressed roamer
- Player has 1 in-game day to fix the roamer's needs before Grimshroud causes the
  roamer to flee the garden permanently
- Adds genuine tension without being punishing if the player is paying attention

---

### 8. Production Buildings ("Resource Dens")
**What VP does:** Honey Hive, Shearing Shed, Milking Shed — roamers visit these
buildings and produce a resource passively over time.

**Habitat version — 2 new building types:**

**Dewdrop Spring**
- Stone basin with glowing water; placed in garden like a shelter
- Bonded roamers visit it during idle time and splash around (joyful animation)
- Every splash visit awards +3 Dewdrops (on top of normal passive income)
- Visual: water ripple shader, small splash particles, roamer bobbing head anim

**Eldermoss Grove**
- A ring of glowing mushrooms; GlowFox specifically is drawn to it at night
- GlowFox visits, circles it, lights up brighter
- Awards 1 Eldermoss every 2 in-game days of GlowFox visits
- Makes Eldermoss feel like a real resource tied to roamer care, not just a rare drop

---

### 9. Roamer Tricks System
**What VP does:** Use the Trick Stick item to teach piñatas tricks. They perform them
spontaneously when idle.

**Habitat version:**
- When a roamer reaches BONDED stage and happiness > 0.9, a new interaction button
  appears: **"Teach Trick"** (in the roamer panel or via a new toolbar item)
- Each species gets one learnable trick:
  - Mossdeer: **"Stardance"** — rears up on hind legs, shakes antlers, sparkle burst
  - Stoneback: **"Shell Spin"** — retracts into shell, spins in place, pops out
  - GlowFox: **"Light Trail"** — dashes in a small circle leaving a glowing particle trail
- Once learned, trick fires randomly during long idle periods (2% per frame)
- Can be triggered manually by player clicking "Perform!" in the roamer panel
- Milestone: teaching all 3 tricks earns "Master Tamer" award

---

### 10. Roamer Sickness / Departure Risk
**What VP does:** Sick piñatas display illness icon, get worse over time, eventually
leave if untreated. Can buy medicine. Creates urgency.

**Habitat version (Priority #3 from previous sessions):**
- When any need (food/safety/warmth) stays below 0.15 for 48+ in-game hours:
  roamer gets a "Burdened" state — hunched posture, darker shader, cough particle
- Burdened state: needs decay 2x faster, happiness drops 0.01/s
- If still burdened for another 24 in-game hours: roamer becomes "Departing" — walks
  slowly toward the garden boundary
- Player intervention: feed them (raises food) OR offer a "Restorative Berry" item
  (sold by Maren, 15 Dewdrops). Restoring a departing roamer → 100 XP + milestone.
- If the roamer exits the boundary: permanent loss, toast: "🌿 [Name] returned to the wild."
- The Grimshroud NPC (above) is the visible tension element of this system.

---

### 11. Blessing / Wild-card Offspring
**What VP does:** In Trouble in Paradise, collecting all hearts in a romance maze with
6+ of the same species gives a chance at a "wild-card" — a rare variant baby.

**Habitat version:**
- When two BONDED parents with happiness > 0.95 breed, there's a 10% chance the egg
  is a **Blessed Egg** — slightly larger, glows gently, hatches faster (5 s vs 30 s).
- Blessed offspring: born with an extra positive trait (chosen from trait list, biased
  toward rarer traits), AND born with a slight shader color tint (warmer gold).
- Milestone: "First Blessed Birth" → 50 XP
- These can't be predicted, just happen — creates the "oh wow" moment VP is known for.

---

## Tier 3 — Roadmap (Big Systems)

### 12. Plant Growth System (Full VP seed loop)
**What VP does:** Every plant has a grow cycle. You plant seeds, they sprout, mature,
flower, fruit. Fruit can be harvested or left for roamers to eat naturally.

**Habitat version:**
- New plant types beyond berry bush: **Moonbloom** (flowers at night, GlowFox loves
  it), **Rootstone Fern** (Stoneback eats its spores), **Eldergrass** (Mossdeer grazes)
- Each plant has 3 stages: sprout → growing → mature
- Mature plants auto-harvest every 2 in-game days and drop an item on the ground
  (roamers path to eat it, or player picks it up via cursor click)
- The planting bounce animation (item #1) makes this feel magical from the start

### 13. Accessory / Cosmetic System
**What VP does:** Buy accessories from Costolot's Store, equip to piñata — hats,
collars, arm bands. Pure cosmetic expression.

**Habitat version:**
- Maren sells accessories: Acorn Cap (Mossdeer), Glowstone Pendant (GlowFox),
  Lichen Wrap (Stoneback)
- Accessories are Node3D meshes attached to a bone or a fixed offset
- Equip via roamer panel "Adorn" button → item appears permanently on roamer
- Saved/loaded as `accessory_id` string on the roamer
- No gameplay effect — purely for expression and personalization

### 14. In-Garden Camera Mode
**What VP does:** A camera item lets you take snapshots of your piñatas.

**Habitat version:**
- Pause normal controls, enter a free-look cam with no UI
- Click to "take photo" → screenshot to file + toast "Photo saved!"
- Roamers don't flee the camera cursor — they stay in pose
- Unlocked at Warden Level 10

### 15. Fence / Zoning Tools
**What VP does:** Place picket fences to divide the garden, keep conflicting species
apart. Roamers respect fences unless provoked.

**Habitat version:**
- New placeable item: **Rune Fence Post** — small glowing stone pillar
- Two posts snap together with a glowing barrier between them (same rune shader
  as the boundary)
- Roamers pathfind around fences
- Player uses fence to zone off a "GlowFox den" area from "Mossdeer meadow"
- Adds satisfying garden layout decisions

---

## Micro-Juice List (Small, Do These Everywhere)

These are the "small satisfying details" you mentioned — VP's secret sauce:

- **Dewdrop pickup sparkle** — when dewdrops generate passively, a tiny sparkle floats
  up from the roamer and drifts toward the HUD counter before counting up
- **Roamer sniff** — occasionally Mossdeer lifts head and sniffs the air (random idle)
- **GlowFox tail wag** — when the player pets it, tail wags 3x with each pet
- **Stoneback startle** — if the player clicks near (not on) a sleeping Stoneback, it
  flinches before shell-retreating
- **Berry bush shiver** — when a roamer eats a berry, the bush shivers slightly
- **Zone unlock camera pan** — when unlocking a zone, the camera briefly pans to show
  the expanded boundary before returning to player
- **Egg wobble before hatch** — the egg rocks side to side for 5 s before cracking open
- **Rain on shelter roofs** — particle emitter on shelter roof during rain, roamers
  inside visible through a window
- **Footprint trail** — roamers leave brief decal footprints on the terrain when walking
  (fade after 3 s)
- **Maren wave** — when the player first opens the garden each session, Maren waves
  toward the camera and says a random one-line greeting

---

## Priority Order for Next Sessions

1. ✅ **Seed planting animation** — pure juice, 1–2 hours, massive feel upgrade
2. ✅ **Egg hatch animation sequence** — already have the system, just needs visual polish
3. ✅ **Breeding heart indicator** — gives breeding system a visible cue
4. ✅ **Roamer sickness / departure risk** — was already priority #3, now designed
5. **Roamer variant system** — adds long-term collectible goal to each species
6. **Species conflict system** — adds live management tension
7. **Soured/Blight Roamers** — big drama moment, rare enough to feel special
8. **Visiting NPC characters (Fernwick first)** — garden feels populated and alive
9. **Tricks system** — rewards bonding with visible personality expression
10. **Production buildings** — gives Eldermoss a proper production loop
