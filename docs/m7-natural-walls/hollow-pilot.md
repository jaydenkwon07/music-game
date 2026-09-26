# M7 natural-walls step — Hollow pilot record

Spec: "M7 — Natural walls spec" (owner, 2026-09-25; Drive). Source grid: "Resonance — The Hollow
(room 1) layout" (owner, 2026-09-25). Tooling: `roomlib.py` rules 1–3 + 3a, `lint_rooms.py`,
`data/lint_baseline.json`. Before-numbers: `lint-before.txt`.

## Owner rulings (2026-09-25)

- **Seam — APPROVED.** Hollow rows 8–9 ↔ Cistern rows 26–27: the Hollow sits beside the
  Cistern's lower screen, a world offset of 18 rows. Safe in code as-is: a `from_*` landing is
  derived from the destination room's own nearest link, never the source link's row.
- **Rock budget — APPROVED at ~73%, for throat-archetype rooms ONLY.** Reason: a one-screen room's
  bounds can't shrink below the camera, and a throat is mostly rock by definition. **Not a general
  precedent** — every other archetype still answers to the 20–30% band.
- **Pilot hours — SKIPPED.** Review rounds are recorded instead (below).
- **Thresholds — SETTLED (round 2): run 3, steps 4, pipe ≤6 wide × 4.** Started stricter (run 2,
  steps 3), loosened in round 1 under "loosen if that's what it takes", kept in round 2. The
  15 Cistern/Gallery baseline entries the loosening left stale were pruned.
- **Grid — v5 (round 2).** Taken forward after review of its dark shots and close-ups; committed
  with the tooling. The throwaway capture scaffolding is deleted at sign-off.

## Spec amendment — rule 3a, `tooth` (owner, round 2)

Warn on any cell 1 tile thick with the other material on both opposite sides — a rock fin or a
floor slot — with the same exemptions as rules 1–3. A warning, like the others. It exists because
a single-tile feature draws as a V-spike under the 45° bevel, and rules 1–3 cannot see a 1-row
zigzag. Results: **Hollow v5 0**; the locked rooms' teeth went into the baseline — Cistern 6
(`[2,16] [9,16] [11,15] [15,20] [29,25] [31,26]`), Gallery 10 (`[13,11] [16,11] [45,8] [47,10]
[48,8] [53,11] [54,12] [56,11] [76,7] [79,7]`). Grey-box rooms: 0.

## Open M8 question — note 1 visible from frame one

Recorded, not changed (owner, round 2). The fixed one-screen camera shows the whole Hollow, and
nothing occludes the pickup's light, so note 1 and its glow are on screen from the first frame —
and the channel's whole silhouette reads at ambient too. The v5 dark shots also show the note's
glow spilling over the tongue into its recess. Two options for M8:

1. **Accept it.** The note is visible from frame one; the tongue's job becomes forcing the detour
   (you see the goal and must walk the S to reach it) rather than hiding it.
2. **Wake the pickup light at the low bend.** The note's light stays off until the player reaches
   the bend (~`[20,13]`), restoring the designed reveal at step ~34 of 47.

**The M7 stranger playthrough tests the as-is version (option 1).**

## Review rounds

1. **Round 1 (2026-09-25) — v3 not approved; captured; alternative requested.** v3 (doc grid +
   12 single-cell edits, lint-clean at the stricter thresholds) rendered its single-cell edits as
   V-spikes under the 45° bevel. Alternatives v4 and v5 drafted at the loosened thresholds.
2. **Round 2 (2026-09-25) — v5 taken forward.** Thresholds settled; tooth rule added (3a);
   visibility recorded as an open M8 question.

## Findings from the capture

- **Single-tile features render as teeth.** Any cell 1 tile thick between the other material on
  both sides (a rock fin or a floor slit) draws as a V-spike. Counts: doc grid 9, v3 14, v4 12,
  **v5 0**. Rules 1–3 do not catch this (a 1-row zigzag is neither a straight run nor a monotonic
  staircase) — now rule 3a (above).
- **Medium features need ≥2 tiles *along* the wall.** A 2-tall, 1-wide stalactite still spikes;
  2×2 reads as a mass.
- **The reveal does not hold in-engine** — see the open M8 question above. The grid's
  line-of-sight still puts first sight at path step 34 of 47, as designed; lighting doesn't enforce it.
- **v3's descent pinch at row 8** (cols 18–19, 2 wide, both walls pinching at once — rule 6).
  Gone in v4/v5 (narrowest 3).

## v3

```
################################
################################
############..#..###############
##########........##############
#########.........##############
#########....#......############
########....####.....###########
#######...#######....###..######
#######....#######..####........
#####.....#######...#####.......
###......#######...#####...#####
###......#######.....##.....####
##......#######...........######
#.......########.#.......#######
##.....############.....########
####..#############...##########
####################.###########
################################
```

## v4

```
################################
################################
###########...#..###############
##########....#...##############
#########............###########
#########...##......############
########....#####....###########
#######....#####....####..######
#######...#######....###........
#####.....#######...###.........
###......#######...####....#####
###......#######.....##.....####
#.......########..........######
#.......##########.......#######
##.....############......#######
####..#############...##########
################################
################################
```

## v5 (taken forward — `data/rooms/room_hollow.json`, captures `hollow-v5-*`)

```
################################
################################
###########...##################
##########....##..##############
#########............###########
#########...##.......###########
########....#####....###########
#######....######...####..######
#######...######...#####........
#####.....######...####.........
###......######....####....#####
###......######......##....#####
#.......########..........######
#.......##########.......#######
##.....############......#######
####..#############...##########
################################
################################
```

## doc grid (as proposed)

```
################################
################################
###########...#..###############
##########........##############
#########..........#############
#########....#......############
########....#####....###########
#######....######...####..######
#######...########...###........
#####.....#######...####........
###......#######...#####...#####
###......#######.....##.....####
##......########..........######
##......##########.......#######
##.....############......#######
####..#############...##########
################################
################################
```
