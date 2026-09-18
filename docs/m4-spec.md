# M4 — Art direction and the first finished room · Specification

**Status:** draft, not started. **Date:** 2026-09-14.
**Expands:** design doc §3.7, §4.1, §4.2, §11.
**Supersedes:** the earlier M4 draft (boss door), which becomes M5
(`docs/m5-spec-boss-door.md`).

---

## 0. Why this milestone exists

Everything so far is deliberately unfinished: gray boxes, code-built tilesets,
placeholder circles. That was correct — M0–M3 were answering whether the *loop*
works, and art would have made those checkpoints expensive.

M4 answers a different question: **can this look like a game someone would buy?**
The owner's assessment of the current build is that it reads like "a crappy pixel
game from the 2000s." That is a solvable and well-understood problem, and it
decomposes into five things (§2), only one of which is drawing skill.

**The method is the same vertical-slice logic that has worked three times now.**
Build **one room to final quality** rather than nine rooms to medium quality. One
finished room tells you whether the palette survives the lighting, whether the
tileset reads at size, whether the character fits the world — and then becomes
the reference every later room is measured against. Nine medium rooms gives you
nine rooms to redo.

---

## 1. Goal and gate

**Goal:** establish the game's visual language, and prove it by building Room A
to a standard nothing else in the project has reached.

**The gate:** *a still screenshot of Room A is something you would put on a store
page.* Not "looks better" — **finished.**

Secondary gate, and the one that actually catches self-deception: **show the
still to someone who has not seen the project and ask what kind of game it is.**
If they say "a pixel game," the style hasn't landed. If they describe a dark cave
where light matters, it has.

---

## 2. The five things that separate polished pixel art from amateur pixel art

Recorded here because they are the whole content of this milestone, and because
only one of them is drawing skill.

1. **Lighting.** 2000s pixel games are evenly lit. Every modern one is built on
   dynamic light. This is the single biggest lever and — for this game — it is
   mechanic and mood simultaneously.
2. **Hue-shifted ramps.** Amateur shading lowers brightness on one hue. Polished
   shading shifts hue as it darkens: shadows drift violet-blue, highlights drift
   warm. This one habit is most of the visual gap.
3. **A real bitmap font.** The project is still on Godot's default, which
   antialiases at low resolution and turns to grey mush when upscaled. Cheapest
   fix on the list.
4. **Motion.** Easing, squash, camera lag, particles, hitstop. A still of Celeste
   next to a still of a bad pixel game is a smaller gap than the moving versions.
   The door currently just *opens*; it should be an event.
5. **Post-processing applied at the right stage.** See §6 — architectural, not an
   effect, and retrofitting it is expensive.

---

## 3. Art direction `[OWNER DECISION — confirm before Step 3]`

### 3.1 The styles considered

| Style | What it is | Verdict |
|---|---|---|
| **Lithic** | Dead grey-violet rock. No saturated colour anywhere except what the player brings. | **Recommended base.** |
| **Resonant architecture** | The cave is carved, not natural — pipes, strings, tuning forks set in stone. Warm brass and wood against cold rock. | **Recommended accent**, concentrated at doors. |
| **Bioluminescent** | Glowing fungus, crystals, living light. | **Rejected.** The most-used indie cave look, and a world that already glows undercuts the emptiness-to-fullness arc. |
| **Negative space** | Near-total void, silhouettes, minimal tiles. | Cheapest and most distinctive, but reads as unfinished to many players. Held in reserve. |

### 3.2 The recommendation, and why

**Lithic base with resonant-architecture doors.**

- **It makes the theme literal.** The world is monochrome until the player brings
  colour. Pillar 2 (emptiness to fullness) stops being a metaphor in the design
  doc and becomes the thing you see.
- **It maximises the lighting system.** Dead rock is the perfect substrate for
  dynamic light; the contrast does the work that detail would otherwise do.
- **It puts expensive art where the player stops.** Ordinary corridors are rock.
  Doors — where the player pauses, reads, performs — are carved, built,
  instrument-like. Art effort concentrates at the moments that matter.
- **Rock is forgiving.** Faces and machinery punish inexperience. Stone does not.

### 3.3 The palette `LOCKED once approved`

Store as `data/palette.json` and reference by name; never a hex literal in a
scene or script.

**Rock ramp** — note the hue drift, which is the point:

| Name | Hex | Hue | Use |
|---|---|---|---|
| `rock_void` | `#0D0B12` | 262° | Unlit, beyond falloff. Reads as black. |
| `rock_deep` | `#1A1723` | 259° | Deep shadow, distant structure. |
| `rock_shadow` | `#2B2738` | 255° | Base shadow. The floor's resting value. |
| `rock_mid` | `#40394F` | 259° | Mid tone, lit floor. |
| `rock_lit` | `#5A5268` | 262° | Directly lit surfaces. |
| `rock_high` | `#7D7589` | 274° | Edge highlight. |
| `rock_edge` | `#A8A0A6` | 327° | Rare brightest edge — note the swing to warm. |

**Note colours** stay as `NoteColors` already generates them: three category arcs
(§4.2). These are the **only** saturated colours in the game. Nothing in the
environment may use them.

**Player**: near-white, cool (`#D8D4E0`). The player must read as the brightest
thing on screen when unlit, because in the cold open they are the only thing.

**Budget: 32 colours total.** Seven rock, twelve note hues, the player, and ~12
for accents, UI and the resonant-architecture materials. **Do not sample outside
the set.** This constraint is what produces coherence; it is not an optimisation.

### 3.4 Resonant-architecture vocabulary (doors only)

Warm materials against cold rock — aged brass `#8A6A3C`, dark wood `#4A3428`,
tarnished copper `#6B7F6A`. Forms to draw from: organ pipes, tuning forks,
tensioned strings, bells, resonating chambers, carved staves.

**Doors are the only place these appear in Act 1.** That restraint is what makes
them read as significant rather than decorative.

---

## 4. The resolution migration `BLOCKING — owner decision`

### 4.1 The numbers

| | Internal resolution | Pixels | Tiles |
|---|---|---|---|
| Current | 320×180 | 57,600 | 20px → 16×9 grid |
| Celeste | 320×180 | 57,600 | — |
| **Proposed** | **640×360** | **230,400** | **20px → 32×18 grid** |
| Undertale | 640×480 | 307,200 | 20px |

The project is at exactly Celeste's resolution — a legitimate, deliberately
chunky look — while the stated reference is Undertale, which has 5.3× more
pixels. The player is 10px tall; Undertale's protagonist is around 30.

**640×360** integer-scales exactly to 1080p (3×) and 1440p (4×), cleaner than
320×180's 6× and 8×.

### 4.2 Correction to earlier advice

An earlier draft proposed **40px tiles, keeping the 16×9 grid**, on the grounds
that `data/rooms/*.json` geometry would need no changes. **That traded the wrong
thing.** With a real art pass in view:

- **20px tiles at 640×360 is exactly Undertale's tile density** — a known-good
  scale for this kind of art.
- **32×18 doubles layout granularity.** 16×9 was already flagged as coarse (144
  cells, ~7 usable rows after walls); it will not survive rooms that need
  interesting geometry.
- **40px tiles are awkward to author** — many pixels per tile, few distinct tiles.

The data cost is a **2× upscale of every geometry grid**: a ten-line script, each
old cell becoming a 2×2 block, with entry points, links, pickups and chimes
doubling their coordinates. Mechanical, scriptable, and verifiable by the
existing boot consistency check.

### 4.3 Why it must happen now

Resolution is the one decision every drawn pixel depends on. Settled now: a
project setting, a tileset regeneration, a coordinate doubling, a HUD resize.
Settled after a tileset, a character and door art exist: all of it redrawn.

**Both answers are legitimate.** 320×180 is a real aesthetic. But it has to be a
decision, not a default.

---

## 5. Lighting — the system

### 5.1 The model

- **`CanvasModulate`** per room, set to `rock_deep` or darker, multiplying the
  world down to near-black.
- **`PointLight2D`** per source, with a soft radial gradient texture.
- **`LightOccluder2D`** on wall tiles, generated from the tileset, so light does
  not pass through stone.
- Lights are **additive**; a lit surface returns toward its true palette value
  rather than being tinted by the light.

### 5.2 What emits light

| Source | Radius | Energy | Notes |
|---|---|---|---|
| Player | ~40px | 0.35 | Grows with notes collected — §5.3 |
| Note pickup | ~60px | 0.8 | In its note colour. The pickup **is** a light. |
| Played note (ring) | 0 → ~90px | 1.0 → 0 | Light travels with the ring and dies with it |
| Door gems | ~25px | 0.4 | Per gem, category colour, brighter when lit |
| Chime | ~30px | 0.5 | Pulses in note colour while playing its melody |

### 5.3 The player's light grows with collection

Radius scales with owned pitch classes — roughly 30px at zero notes to 70px at
twelve. **This is Pillar 2 made mechanical.** The player literally sees more of
the world as they accumulate, and the cold open is genuinely dark because they
genuinely have nothing.

It also quietly solves a design problem: early rooms are claustrophobic and late
rooms legible, with no per-room tuning.

### 5.4 Constraint

**Lighting must not gate solvability.** A player should never fail to find a
pickup or a door because it was too dark. Every interactable emits its own light
(§5.2), so it announces itself before the player can see the floor around it.
The rule: **objects are visible before terrain is.**

---

## 6. The post-processing pipeline `ARCHITECTURAL — build before wanting effects`

**Post-processing goes after the upscale, never before.**

Applying bloom to the 640×360 buffer and then scaling 3× produces blocky bloom,
which reads as a mistake rather than a style. Modern pixel games render the world
at low resolution, upscale with nearest-neighbour, then apply bloom and vignette
at full output resolution.

In Godot: the world renders into a `SubViewport` at 640×360 with
`texture_filter = NEAREST`; the `SubViewportContainer` scales to the window;
post-process shaders attach to the container, not the viewport.

**Build this in Step 2 even with no effects attached.** Retrofitting means
changing how everything renders. Effects to enable later: a restrained bloom on
note colours only — they are the brightest things on screen, so the threshold
does the selection for you — and a subtle vignette.

---

## 7. Typography

Replace Godot's default with a **bitmap pixel font**. Criteria:

- Designed at a fixed pixel size (8px or 10px cap height at 640×360).
- No antialiasing. Import with filtering **off**.
- Full Latin set plus punctuation; digits that read at size.

Worth evaluating: `m5x7` and `m6x11` (Daniel Linssen), `Pixel Operator`. Check
each licence before shipping — do not assume.

**Never scale a bitmap font non-integer.** For a larger size, use a font designed
at that size rather than the small one scaled up.

---

## 8. Object silhouettes — a correctness fix, not a style pass

Measured on the current build: a chime is rgb(109,117,145), a pickup is
rgb(58,110,222). Both are circles of the same size. **A chime reads as a disabled
pickup**, which is the exact visual language `NoteColors.dormant()` uses for an
unlit gem.

This is why a player can walk past both chimes and never discover clue delivery —
and clue delivery is most of what M3's gate tests.

**Every interactable type must be distinguishable by silhouette alone**, with
colour removed:

- **Pickup** — a floating, rotating shape. Small, bright, clearly takeable.
- **Chime** — vertical and struck-looking. A hanging bar, a fork, a pipe. **Not
  round.**
- **Door gem** — set into a frame, geometric, clearly inert until lit.
- **Player** — the only thing with a character silhouette.

Test: render the room pure black-on-white and confirm every object type is still
identifiable.

---

## 8a. Asset production order

**The order matters more than the timing, and it is the opposite of what feels
natural.** The instinct is to draw the exciting things first — the door, the
character, a crystal. Do that and you get beautiful objects that don't sit
together, because nothing has yet established the light, the value range, or the
scale they all share.

1. **The tileset**, even though it is the least interesting. It sets the value
   range every other asset must live inside. Once the floor is `rock_shadow` and
   lit surfaces are `rock_mid`, you know exactly how bright a pickup has to be to
   read against it. Draw the pickup first and you are guessing, then re-guessing.
2. **The player**, because the player establishes scale. Every other object is
   sized relative to the character, and if the character changes, everything
   changes with it.
3. **Interactables — silhouette before colour.** Pickup, chime, gems, to the
   rules in §8. Get them distinguishable in black-on-white, *then* colour them.
4. **Doors**, last of the important assets — most expensive, most
   style-dependent. By then the rock is settled and the light works, so you know
   what "warm brass against cold stone" actually has to contrast with.
5. **Background props, last and fewer than expected.** In a lit cave most depth
   comes from light falloff, not drawn detail — structures fade to silhouette as
   they leave the light pool. A handful of props, and darkness does the rest.
   Dark games need shorter asset lists than bright ones, which is a further
   argument for the lithic direction.

### Two hard prerequisites

**Lighting must exist before the tileset is drawn** (which is why Step 2 precedes
Step 3, and it is not an arbitrary ordering). Tiles drawn before the lighting
system will have shading baked into them, and the dynamic light will then light
them a second time. Everything ends up muddy and flat at once, and the fix is
redrawing the tileset.

**Draw tiles flat, in palette values, with form but not lighting.** Let
`PointLight2D` do the lighting. A tile should look slightly boring in isolation
and correct in the room.

**The resolution decision (§4) gates all of it.** Nothing gets drawn before Q27
is answered.

### A practical note on the placeholder

Build the Step 0 placeholder tileset at the **real tile dimensions and with the
real slot layout** — same tile ids, same atlas positions, same collision shapes,
just flat colour blocks instead of art. Step 3 then replaces pixels only. Nothing
that references a tile id needs re-authoring, and the geometry data never moves.

---

## 9. Motion and game feel

A still cannot show this and it is half the difference. Minimum for Room A:

- **Player movement** — the acceleration and deceleration `@export`s have never
  been tuned. Tune them now; there is finally a reason to move.
- **Camera** — a small lag on follow, still clamped to room bounds. Not so heavy
  it feels detached.
- **Note played** — the ring already eases out. Add a brief light flash and a few
  particles in the note's colour.
- **Pickup collected** — the note's light expands and folds into the player's own
  light. Makes "I gained this" legible without UI.
- **Door unlock** — currently the door just opens. It should be the biggest event
  in the room: a held beat, gems flaring in sequence, a shake, dust, the melody
  resolving. **This is the payoff for the entire loop; it should feel like one.**
- **Instrument state entry** — dim and panel ease in over ~0.2s, not a cut.

Keep every one of these on the pixel grid. **Never rotate or non-integer-scale a
pixel sprite** — rotate by swapping frames, scale by integers only.

---

## 10. Step ladder

Stop after each for the owner to run.

**Step 0 — Resolution migration.** *Gated on §4 approval.*
640×360; tiles stay 20px; write the 2× grid upscale script; double all geometry
coordinates; regenerate the placeholder tileset; resize HUD.
**Done when:** the slice plays identically at 640×360, rooms are 32×18, the
camera clamps with no void, and the boot consistency check passes.

**Step 1 — Palette and font.**
`data/palette.json`; swap in the bitmap font; retint every existing placeholder
to palette colours. Still gray boxes — but *the right* gray boxes.
**Done when:** no colour on screen is outside the 32, and no text is antialiased.

**Step 2 — Lighting and the render pipeline.**
`CanvasModulate`, `PointLight2D` on the player and every interactable, occluders
from the tileset, the player's growing radius, and the `SubViewport` pipeline
from §6 with no effects attached yet.
**Done when:** the room is genuinely dark, objects announce themselves before
terrain does, and walls cast shadow.

**Step 3 — The tileset.** *Gated on §3 approval.*
Real cave tiles at 20px in the rock ramp: floor, wall, wall-top edge, inner and
outer corners, a few variants to break repetition, one or two rare detail tiles.
**Done when:** Room A's geometry is drawn in real tiles with no visible tiling
pattern at a glance.

**Step 4 — Object art.**
Player, pickup, chime, door frame, gems — to the silhouette rules in §8. Doors
get the resonant-architecture treatment.
**Done when:** the black-on-white silhouette test passes.

**Step 5 — Room A to completion.**
Composition, light placement, detail tiles, depth. Treat it as a single image
that happens to be playable.
**Done when:** the §1 gate — a still you would put on a store page.

**Step 6 — Motion pass.**
Everything in §9, tuned by feel on the finished room.
**Done when:** the door unlock feels like the payoff of the loop.

**Step 7 — Record.**
`docs/m4-progress.md`; update `CLAUDE.md` §2/§7/§8 and the design doc. Capture a
reference still of Room A — later rooms are measured against it.

---

## 11. Non-goals

- **The other rooms.** One room, finished. B, C and D stay gray until Room A sets
  the reference.
- **The boss door** — now M5.
- **Combat**, enemies, damage, death.
- **Real music.** The synth stays a placeholder sine. *Note: M1's aesthetic gate
  triggers the first time a real instrument voice exists — so composing audio is
  deliberately not in this milestone.*
- **New clue-delivery vectors** beyond making the chime read correctly.
- **A UI redesign** beyond the palette, font, and the HUD fixes already specified
  (hide the note bar during the instrument state; key labels show the key the
  player would actually press).
- **Animation systems.** Room A needs at most a walk cycle and an idle.

---

## 12. Decisions

- **D-M4-1 — One room to final quality, not several to medium.** Same
  vertical-slice logic as M0–M3. One finished room becomes the reference; nine
  medium rooms become nine rooms to redo.
- **D-M4-2 — Lithic base, resonant-architecture doors.** Makes the
  emptiness-to-fullness theme literal, maximises the lighting system,
  concentrates expensive art where the player stops, and avoids the over-used
  bioluminescent cave.
- **D-M4-3 — 640×360 with 20px tiles, 32×18 grid.** Corrects the earlier
  40px/16×9 proposal, which preserved data stability at the cost of layout
  granularity and authoring sanity. The 2× grid upscale is scriptable.
- **D-M4-4 — Post-processing after the upscale.** Architectural; the
  `SubViewport` pipeline goes in at Step 2 even with no effects attached.
- **D-M4-5 — The player's light radius scales with notes collected.** Pillar 2
  made mechanical, and it removes the need for per-room visibility tuning.
- **D-M4-6 — Objects are visible before terrain.** Every interactable emits its
  own light, so darkness never gates solvability.
- **D-M4-7 — Silhouette distinctness is a correctness requirement.** The chime
  currently reads as a disabled pickup, which defeats clue delivery.
- **D-M4-8 — 32 colours, no sampling outside the set.** The constraint produces
  coherence; it is not an optimisation.
- **D-M4-9 — Assets are drawn tileset → player → interactables → doors → props.**
  The tileset sets the value range and the player sets scale; drawing the
  interesting things first produces objects that don't sit together.
- **D-M4-10 — Tiles are drawn flat, with form but no baked lighting.** Lighting
  exists before the tileset (Step 2 before Step 3) precisely so the art doesn't
  get lit twice. Baked shading plus dynamic light reads as muddy, and the fix is
  a redraw.
