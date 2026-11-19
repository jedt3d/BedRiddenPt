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
3. ✅ Build tasks go to **GitHub issues**. ⚠️ Pending: `git init` + repo creation need the user's explicit yes, repo name and visibility.

## Build plan (not started — needs user go-ahead)

Order: 0 → 1, then 2/3/4/5 any order, then 6, then 7, then 8. Figma needed before Phase 2. Estimate ≈ 2 h 45 min (SPEC §9 still says 1 h 45 min).

| Task | State |
|---|---|
| 0.1 `flutter create` CupertinoApp · 0.2 packages + assets in pubspec · 0.3 Info.plist | todo |
| 1.1 open DB + schema + FK · 1.2 first-launch seed 5 random · 1.3 repository (incl. mark deceased/restore) · 1.4 reset keeps name | todo |
| 2.1 one-time name screen · 2.2 PIN entry · 2.3 ⋮ Reset sample data on PIN screen | todo |
| 3.1 rows · 3.2 search/filters · 3.3 Show inactive · 3.4 swipe deceased + swipe restore | todo |
| 4.1 tiles + outline · 4.2 colored pins · 4.3 pin → detail · 4.4 legend + OSM attribution | todo |
| 5.1 fields + BE dates + mini map · 5.2 Call/Navigate/Edit | todo |
| 6.1 fields + pickers · 6.2 prefill from pool · 6.3 validation + duplicate block · 6.4 deceased read-only | todo |
| 7.1 Use my location ±m · 7.2 photo pick + copy | todo |
| 8 Simulator walkthrough | todo |

## Risks

- Reset sample data on the PIN screen works without the PIN (accepted for prototype).
- PIN is a constant `000000` in code; volunteer name in plain `shared_preferences` (SPEC §2, accepted).
- No git repo: no history/rollback for the shared folder; several sessions write here.
- OSM tiles need a real User-Agent; no bulk/offline download (SPEC §8).
- `SPEC.md` §9 still says 1 h 45 min; the 25-task plan estimates 2 h 45 min.
