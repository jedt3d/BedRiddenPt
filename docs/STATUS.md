# Status — BedRiddenPt

Updated 2026-11-19 by the hub session. ✅ = checked on disk · ⚠️ = not confirmed / mismatch.

## Sessions

| Session | Doing | Last result | State |
|---|---|---|---|
| map-geo | Geo assets + map spike | ✅ `assets/geo/` (boundary 1, subdistricts 4, water 2, roads 386 ways / 206 distinct `name:en`); helpers in `spikes/map_geo/lib/geo/`; spike `flutter test` 5/5 pass (re-run by hub); spike's asset copies identical to `assets/`. Simulator run: screenshots in `spikes/map_geo/docs/`, not re-run | idle, reports to hub |
| sample-data | 50-patient pool | ✅ `assets/bootstrap.json` 50 records, 25/25, ages 60–110 (4 aged 100+), 10/25/15 care levels, 43/3/2/2 status; `data/patients.csv` 50 rows; 50 avatars. Generator imports the spike's `lib/geo/` helpers (don't move them) | idle, reports to hub |
| figma-proto | Figma frames for every screen | [Figma file](https://www.figma.com/design/zHNLIMNEn1XPcNwBTZGw7B), 25 frames, 67 links, updated to the fixed-PIN/name screen and swipe-restore (user-approved). 15 design decisions handed off for SPEC (notes: `figma-prototype.md`). Hub checked the frame list (25) and the texts of frames 07, 13, 16, 17, 22, 23, 25 against SPEC | done |

Matt Pocock skills (`~/.claude/skills/`: to-tickets, triage, to-spec, wayfinder, grill-with-docs, handoff) are owned by the hub. No ADRs yet; candidates: "one registration, no visit history", "no delete, soft statuses".

## User decisions

Answered 2026-11-19 and written into `SPEC.md` (draft 3 change list, §2, §4, §6, §7):
1. ✅ PIN fixed at `000000`; one-time "Your name" screen on first launch.
2. ✅ Restore deceased by swipe left (Show inactive on) → green Restore + confirm; form link dropped.
3. ✅ Build tasks are GitHub issues #1–#28 (0.4 tokens added later as #28) on [jedt3d/BedRiddenPt](https://github.com/jedt3d/BedRiddenPt/issues) (public; git initialised, `main` pushed). The plan has 27 tasks, not 25. Each issue has a 'Done when' line and a 'Blocked by' line.

## Spec questions — all resolved 2026-11-19

The user adopted figma-proto's 15 design decisions plus: "Use my location" also sets the subdistrict; moved patients can be swiped to Deceased; birth_year CHECK stays 1916–1966 (known limit, app checks age). Hub defaults, not asked: ⋮ = CupertinoActionSheet; bad checksum text "This national ID isn't valid. Check the 13 digits."; `neighbour`/`other` unused in sample (no change). All in `SPEC.md` §5, §7 and the draft-3 change list; GLOSSARY adds **Care needs**; 17 issues carry spec-update comments.

## Build plan (not started — needs user go-ahead)

Order: 0 (incl. 0.4 tokens) → 1, then 2/3/4/5 any order, then 6, then 7, then 8. Figma needed before Phase 2. Estimate ≈ 2 h 45 min (SPEC §9 still says 1 h 45 min).

| Task (issue) | State |
|---|---|
| 0.1–0.3 setup (#1–#3) | todo |
| 0.4 design tokens + no-raw-values check (#28; source `design/tokens.json`; blocks #8–#27) | todo |
| 1.1–1.4 data (#4–#7) | todo |
| 2.1–2.3 name / PIN / reset (#8–#10) | todo |
| 3.1–3.4 list, incl. swipe deceased/restore (#11–#14) | todo |
| 4.1–4.4 map (#15–#18) | todo |
| 5.1–5.2 detail (#19–#20) | todo |
| 6.1–6.4 form (#21–#24) | todo |
| 7.1–7.2 location / photo (#25–#26) | todo |
| 8 Simulator walkthrough (#27) | todo |

## Risks

- Reset sample data on the PIN screen works without the PIN (accepted for prototype).
- PIN is a constant `000000` in code; volunteer name in plain `shared_preferences` (SPEC §2, accepted).
- Repo is **public**: everything pushed (sample pool, avatars) is world-readable. OSM-derived `assets/geo/` is ODbL; attribution is in its README and all 4 files (checked). Several sessions write in the folder; only the hub commits so far.
- OSM tiles need a real User-Agent; no bulk/offline download (SPEC §8).
- `SPEC.md` §9 still says 1 h 45 min; the 25-task plan estimates 2 h 45 min.
