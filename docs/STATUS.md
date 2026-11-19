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

## Build streams (started 2026-11-19, plan approved by the user)

Hub = `local_5da246be-abad-48fb-9bcf-aa582f9ab9b5` (sole writer of this file; reviews and merges PRs with `gh pr merge --squash --auto` after the Done-when check). Merge rule for stacked PRs: retarget the next PR to `main` before merging, merge commits, delete branches only at the end (`--delete-branch` on #29 closed #30/#32). Main session (`local_78971f4d-…`) reports to the user every 15 min while workers run. Workers: Opus 5.5 / medium, own worktree, one PR per issue. Expert (`local_08d17d04-48b6-4415-be2b-997a359bfb43`, plan mode, read-only; user switches it to Fable 5.2 / high) is consulted after 3 different failed attempts, or at once for Xcode/Pods/signing.

| Stream | Issues | Session | State |
|---|---|---|---|
| A Foundation | #1 #2 #3 #28 #4–#7 + app shell | `local_59b6642d-5dbc-4480-aa09-e71f477cecd2` | **merged** (#29, #38, #39, #33–#37, #40 review fixes); issues #1–#7, #28 closed; branches deleted. Pending: Simulator check on a fresh install (5 active seeded, relaunch same ids, name → PIN → Home) |
| Expert review | #6 repository, #28 tokens, shell | expert | done, fixes merged in #40: no blockers; 2 high + 6 medium + token fixes sent to stream A as one fix PR (shared `lib/shared/`, `lib/geo/`, repository guards). Hub decision: seed/prefill from active pool only (SPEC §6) |
| B1 Launch | #8 #9 #10 | `local_30dee9da-0a6c-4d7f-88c0-272ca65919a1` | code complete: #41 #43 #46 merged (#8–#10 closed); Simulator check queued (2nd) |
| B2 List | #11–#14 | `local_c986f8ba-c4b0-4f23-9746-192822d2efd1` | **done**: #42 #48 #49 #52 merged (#11–#14 closed); Simulator check not yet run |
| B3 Map | #15 #16 #18, then #17 after #19 | `local_7bc2fad5-26bd-492c-bebe-db9f81c515f6` | code complete: #44 #50 #51 merged; #53 (#17) open, waits for main to go green; Simulator queued |
| B4 Detail | #19 #20 | `local_6ae3d0a3-a60e-402e-a4f9-6b3926fa0e8c` | code complete: #45 #47 merged (#19 #20 closed); **holds the Simulator** for its visual check |
| C Form + D Location/photo | #21–#24, then #25 #26 (merged into one stream: same `lib/features/form/` folder) | `local_1de03b92-225a-48df-a0c6-3024990825a9` | running |
| E Walkthrough | #27 | — | after all |

## Build plan (issue list)

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

## ⚠️ main CI red since #45 (2026-11-19)

`lib/features/detail/detail_screen.dart:287`: the header Row (sex · Born …) overflows at phone width; `test/features/list/rows_test.dart` (row tap → Detail) catches it. Each PR passed alone; the combination failed. B4 is fixing it. Hub change: after each merge, the hub now waits for main's own CI run; ask the user about "require branches up to date" protection.

## Token gaps (logged, not blocking)

- Avatar tint: accent at 15 % has no opacity token; B1 uses a local const in `pin_screen.dart`.

## Risks

- Reset sample data on the PIN screen works without the PIN (accepted for prototype).
- PIN is a constant `000000` in code; volunteer name in plain `shared_preferences` (SPEC §2, accepted).
- Repo is **public**: everything pushed (sample pool, avatars) is world-readable. OSM-derived `assets/geo/` is ODbL; attribution is in its README and all 4 files (checked). Several sessions write in the folder; only the hub commits so far.
- OSM tiles need a real User-Agent; no bulk/offline download (SPEC §8).
- `SPEC.md` §9 still says 1 h 45 min; the 25-task plan estimates 2 h 45 min.
