# Status — BedRiddenPt

Updated 2026-11-19 by the hub session. ✅ = checked on disk · ⚠️ = not confirmed / mismatch.

## Sessions

| Session | Doing | Last result | State |
|---|---|---|---|
| map-geo | Geo assets + map spike | ✅ `assets/geo/`: boundary 1 feature, subdistricts 4, water 2, roads 386 ways / 206 distinct `name:en`. ✅ `spikes/map_geo/lib/geo/{random_points,nearest_road}.dart`. ⚠️ Simulator run not re-checked | idle |
| sample-data | 50-patient pool | ✅ `assets/bootstrap.json` 50 records, 25/25 sex, ages 60–110 (4 aged 100+), 10/25/15 care levels, 43/3/2/2 status; `data/patients.csv` 50 rows; `assets/avatars/` 50 PNGs | idle |
| figma-proto | Figma frames for every screen | ⚠️ No Figma URL reported yet | working |

## User decisions

Answered 2026-11-19 and written into `SPEC.md` (draft 3 change list, §2, §4, §6, §7):
1. ✅ PIN fixed at `000000`; one-time "Your name" screen on first launch.
2. ✅ Restore deceased by swipe left (Show inactive on) → green Restore + confirm; form link dropped.
3. ✅ Build tasks are GitHub issues #1–#27 on [jedt3d/BedRiddenPt](https://github.com/jedt3d/BedRiddenPt/issues) (public; git initialised, `main` pushed). The plan has 27 tasks, not 25. Each issue has a 'Done when' line and a 'Blocked by' line.

## Build plan (not started — needs user go-ahead)

Order: 0 → 1, then 2/3/4/5 any order, then 6, then 7, then 8. Figma needed before Phase 2. Estimate ≈ 2 h 45 min (SPEC §9 still says 1 h 45 min).

| Task (issue) | State |
|---|---|
| 0.1–0.3 setup (#1–#3) | todo |
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
- Repo is **public**: everything pushed (sample pool, avatars) is world-readable. Several sessions write in the folder; only the hub commits so far.
- OSM tiles need a real User-Agent; no bulk/offline download (SPEC §8).
- `SPEC.md` §9 still says 1 h 45 min; the 25-task plan estimates 2 h 45 min.
