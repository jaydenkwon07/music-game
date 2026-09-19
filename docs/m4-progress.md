# M4 — Art direction and the first finished room · Progress

**Status: CLOSED 2026-09-18 as a code milestone; the drawn-art steps are
deferred.** The systems/code steps are built and verified — Steps 0–2 (resolution,
palette + font, lighting + render pipeline), **Step 4** (object silhouettes) and
**Step 6** (motion / game feel). The **drawn-art steps — 3 (real cave tileset) and
5 (Room A composed to store-page quality) — and therefore the §1 gate itself — are
consciously deferred to a future milestone** (owner decision, 2026-09-18, while
re-planning the roadmap). This is a conscious close with the gate **not met, not
faked**: `rock_tileset.gd` is still a procedural placeholder.
**Date:** 2026-09-18.
**Spec:** `docs/m4-spec.md`. **Gates:** both owner sign-offs approved (2026-09-18)
— the §4 resolution decision (Q27) and the §3 art direction — so this work builds
on **960×540 / 32×18** and the lithic-base / resonant-doors direction. (Resolution
was first set to 640×360, then bumped to 960×540 the same day — see Step 0.)

What M4 delivered: the game's technical visual foundation — a fixed-resolution
pixel-art render pipeline, a data-driven environment palette, a dynamic lighting
model, distinct object silhouettes, and a full motion/game-feel pass including the
door-unlock payoff. What it deliberately did **not** deliver: the hand-drawn art
that makes Room A a store-page still. That art is a future milestone's work.

---

## What's in

### Step 0 — Resolution migration → done (in two steps)

- **First: 320×180 → 640×360**; tiles stayed 20px, so rooms went **16×9 → 32×18**
  (§4.2, D-M4-3). `scripts/migrate_rooms_2x.py` doubled every room geometry file;
  on-screen pace preserved (`max_speed` 80→160, HUD ×2, `DOOR_INSET` 2→4).
- **Then, same day: 640×360 → 960×540** for finer detail while staying integer-clean
  (×2→1080p, ×4→4K). This time the **32×18 grid was kept and the tile size changed
  20→30px** (960/32 = 540/18 = 30), so a room still exactly fills the viewport (no
  void) with **no geometry re-migration** — the grid data is resolution-independent
  (tile coordinates), and the validator still passes unchanged. Every absolute
  world/screen dimension scaled ×1.5 to hold proportions (player 20→30px, speed
  160→240, light/ring/object/HUD sizes, and the Step 6 fx values); the grid *counts*
  did not move.
- Render root `scenes/main.tscn` + `scenes/main.gd`: the world renders into a
  **fixed 960×540 `SubViewport`**, shown through a `Display` `TextureRect` that
  upscales to fill any window, letterboxed, nearest-filtered. `project.godot`
  window is now 1920×1080 (×2), stretch disabled (the SubViewport owns scaling).

### Step 1 — Palette and font → done

- `data/palette.json`: the locked 7-colour **hue-shifted rock ramp** plus player,
  resonant-architecture materials, UI inks, and the `cave_ambient` modulate value
  (§3.3).
- New `EnvPalette` autoload loads it and resolves colours **by name**; wired into
  11 scene scripts. No environment hex literal survives in a scene or script — the
  one rule's environment corollary holds, and rewriting `palette.json` retints the
  world with no code change. Unknown names return magenta so a typo shows.
- **Silkscreen** bitmap pixel font set as the project theme font
  (`assets/fonts/`, OFL); `note_bar` reads the theme font instead of the
  antialiasing engine fallback.
- The twelve saturated **note hues stay in `NoteColors`**, generated — still the
  only saturated colours in the game (§3.3).

### Step 2 — Lighting and the render pipeline → done

- `scenes/fx/lighting.gd`: a shared **additive `PointLight2D` factory** with one
  cached soft-radial gradient texture. Additive so a lit surface returns toward
  its true palette value rather than being tinted (§5.1).
- `CanvasModulate` in `world.gd` multiplies the world down to `cave_ambient`; UI
  `CanvasLayer`s stay full-bright.
- Lights on the **player** (shadow-casting, radius **grows with collection** —
  §5.3 / D-M4-5, `light_min_radius`→`light_max_radius` by owned pitch classes),
  **pickups** (in their note colour — the pickup *is* a light), travelling **note
  rings**, **door gems**, and **chimes**. Objects announce themselves before
  terrain (§5.4 / D-M4-6).
- The §6 pipeline exists with **no post-process effects attached yet** (bloom /
  vignette deferred, as specified — they'll attach to the `Display`, running after
  the upscale).

### Step 3 — tileset → procedural placeholder only

- `scenes/rooms/rock_tileset.gd` replaces M3's `gray_tileset.gd` (deleted): a
  **procedurally-built** palette-tinted atlas with *form but no baked lighting*
  (§8a / D-M4-10) — floor speckle variants + a rare detail tile, and 16
  adjacency-masked wall tiles with a seam-crack where wall meets floor.
  `room.gd` computes the wall mask and a deterministic per-cell floor variant
  (spatial hash, not RNG — determinism matters).
- This is "the right gray boxes," **not** the hand-drawn cave art Step 3's gate
  asks for. Real tiles can replace this atlas with no other change — nothing
  outside `rock_tileset.gd` knows how a tile looks.

### Step 4 — object silhouettes → pickup + chime done

The live D-M4-7 defect: `note_pickup` and `melody_chime` both drew the same
circle, so a chime read as a disabled pickup and a player missed clue delivery in
M3 testing. Fixed by making the two types differ on three axes at once, so the
read survives the dark overlay and the colourblind case (§6, §8 silhouette test):

- **Pickup — a floating diamond.** A 4-point polygon in the bright note colour,
  slowly spinning and bobbing. The animation lives entirely in `_draw` (a `_t`
  accumulator + `queue_redraw`), so the Area2D collision and `interact_point`
  never move — "clearly takeable" costs nothing in interaction geometry.
- **Chime — a hanging vertical bar with a top mount**, struck-looking and not
  round, in cool stone (`rock_lit`). When struck it rings: the bar tints toward
  the sounding note's colour and a sound-wave ring clears it. That pulse is the
  only note colour the chime ever shows — its resting form is stone (resonant
  materials stay doors-only in Act 1, m4-spec §3.4).

Player (a near-white square) and door gems (a geometric row set into the slab
frame) already read as distinct types, so Step 4 is scoped to the pickup/chime
pair — the actual defect. The black-on-white silhouette test (§8) is the standing
gate.

### Step 6 — motion / game feel → built (feel is owner-tuned)

Mechanisms with `@export` knobs; the numbers themselves are the owner's to dial by
feel on `godot .` (§10):

- **Camera follow-lag** — `Camera2D.position_smoothing` enabled from `player.gd`
  (`camera_follow_speed`, 0 disables); pixel-snapped so it doesn't shimmer, and
  `World.reset_smoothing()` on room-enter keeps teleports from smearing.
- **Note played** — a few sparks in the note colour via a reusable, self-freeing
  `scenes/fx/particle_burst.gd`, alongside the existing ring/light flash.
- **Pickup collected** — `scenes/fx/collect_flash.gd`: the note's light lifts off
  the pickup and travels into the player, folding into the collection-grown light.
- **Door unlock (the payoff)** — a choreography in `door.gd`: held beat → gems
  flare in sequence → camera shake (new `NoteBus.shake_requested`, applied by
  `World` as decaying whole-pixel offsets) → dust burst → the melody re-played as a
  resolving arpeggio through the placeholder synth → open. The lock is disarmed
  first so the arpeggio can't re-enter matching.
- **Instrument entry** — the scrim fade nudged to ~0.18s and the keyboard panel
  eases in with it (modulate tween) rather than popping.
- **Refactor:** the door's gem visuals were extracted to `scenes/objects/door_gems.gd`
  so the choreography didn't push `door.gd` further past the line guideline;
  `Door.CATEGORY_REP_INDEX` stayed on `Door` (the keyboard strip references it).

---

## Deferred to a future milestone (not part of closed M4)

These were M4 steps on paper; on closing M4 they move forward, to be folded into
the re-planned roadmap (owner, 2026-09-18):

- **Step 3 — real cave tileset** (drawn art; `rock_tileset.gd` is the placeholder
  it replaces).
- **Step 5 — Room A composed to store-page quality** — this *is* the §1 gate.
- **Step 7 — reference still of Room A** — can't be captured until 3 + 5 exist.
- **Post-processing effects** (bloom / vignette) — the render pipeline is built to
  host them; none attached.

The lighting, palette, silhouettes and render pipeline this milestone built are
exactly the substrate that art work plugs into, so nothing here is blocked on
re-work — only on drawing.

---

## Deviations and decisions

- **Bare `SubViewport` + manual input forwarding**, not a `SubViewportContainer`
  (which the §6 prose leans toward). A bare viewport receives no input on its own,
  so `main.gd` forwards `_unhandled_input` via `push_input`. Movement polls Input
  directly and is unaffected; notes/interact/octave/Tab go through the forward.
  (See the headless-input-testing memory: `SubViewportContainer` auto-forwards
  keyboard — choosing the bare viewport means that forwarding is now ours to own.)
- **Undertale-style edge-band transitions** were added in `room.gd` alongside the
  migration (owner call): the exit trigger is a thin band right at the room
  boundary and a `from_*` entry lands one tile inside the destination's mirrored
  edge, so walking off one room's right edge arrives at the next room's left at the
  same height. An `_opening_offset` centres the trigger/door on the now-2-tile-wide
  migrated openings. Beyond the pure §4 migration, but adjacent to it.
- **Silkscreen** chosen for the font; the spec only *suggested* m5x7 / m6x11 /
  Pixel Operator as worth evaluating. Silkscreen is a fixed-size OFL pixel font —
  swappable via the project theme with no code change.
- **Tileset built in code**, continuing M3's choice: a runnable slice without an
  editor-authoring step, pinned to `EnvPalette`. Step 3's real art drops into the
  same atlas later.

---

## Verification

- 53 unit tests pass (32 melody-matcher, 21 keyboard-geometry).
- `scripts/validate_rooms.py` passes on the migrated rooms.
- Headless import boots clean.
- **Owner run-verify: pending** — everything visual/felt (the dark cave reading,
  light falloff, transitions, the retinted world) is the owner's source of truth
  on `godot .`. The §1 store-page gate and the §8 silhouette black-on-white test
  are not yet runnable (Steps 3–4 art not drawn).
