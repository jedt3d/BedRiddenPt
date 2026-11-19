# Lessons learned — BedRiddenPt prototype

Date: 2026-11-19 · Written by the main session. Sources: this session's own work and checks, the side sessions' reports, and GitHub issue and PR timestamps. The workers' and the expert's full transcripts were not read.

**Status when written:** every feature is merged: 34 of 36 PRs and 27 of 28 issues. The final Simulator walkthrough (#27) has not run yet.

## Summary

| | |
|---|---|
| Goal | A Flutter (Cupertino) prototype for volunteers to register elderly patients' home locations and care levels in Khlong San district, Bangkok |
| Build time | First PR opened 17:16 ICT; all features merged by about 19:06 ICT (≈ 2 h for 27 issues) |
| Estimate | 2 h 45 min for the build plan. The original "1–2 hours" goal covered building only, not the spec, data and design work before it |
| Shape | Spec questions → glossary → Figma → 28 GitHub issues → a hub session plus parallel worker streams → a timeline page |

## Pros: what worked

- **Settling the spec before building.** Two rounds of questions (`grill-with-docs`), `GLOSSARY.md` and a 25-frame Figma prototype meant most decisions were made before any code.
- **Small, connected tasks.** Each issue had a "Done when" and a "Blocked by" line, which let four screen streams run at once without clashing.
- **Testing the risky parts early.** The map spike (`spikes/map_geo/`) proved `flutter_map`, OpenStreetMap tiles and the Simulator location before the build, and the map work then went smoothly.
- **Sample data from a script.** `data/gen_bootstrap.dart` uses a fixed seed with automated checks, so every change could be regenerated and re-verified.
- **Checking reports against the files.** This caught the wrong map area, stale data copies and the GitHub permission on the wrong account.
- **One hub owning shared files.** After the hub took over `SPEC.md`, `GLOSSARY.md` and `docs/STATUS.md`, the conflicting edits stopped.
- **A dependency timeline.** The `/build-timeline` page made progress and blockers visible at a glance, and it is now a reusable skill.

## Cons: surprises that cost time

| # | What happened | Cost | Root cause |
|---|---|---|---|
| 1 | The map session built the Khlong San **subdistrict** instead of the district | Geo files and spec rows redone | The area was ambiguous, and the session started before the answer came in |
| 2 | Messages between sessions crossed (age range, subdistrict names, road names, spec edits) | Repeated corrections | No single owner for shared files until the hub existed |
| 3 | The sample data was generated 4–5 times (ages, avatars, romanized text, contact fields, road names) | Several regeneration rounds | Data was generated before the glossary, assets and ranges were settled |
| 4 | The avatar portraits only go up to age 90 | 4 patients aged 100+ instead of 11 | The assets arrived after the data rules were set |
| 5 | The PIN and restore decisions changed after the Figma frames were drawn | Frames 01, 03/04 and 14 redone | Decisions came after design |
| 6 | The design-tokens task (#28) was added after the plan and blocked all 20 UI issues | A new step on the critical path | Not in the original plan |
| 7 | GitHub refused the CI workflow file: the jedt3d token lacked the `workflow` scope, and the first refresh went to the other account | A stall plus two approval attempts | No check of the Mac and accounts before the build |
| 8 | 9 stacked PRs waited on #29's Simulator check | The foundation merged in a queue | Stacked PRs depend on the first one merging |
| 9 | Sessions waited on the user for permissions, Simulator access and starting workers (a message-started turn can't start sessions) | Idle time | Approvals were asked for one at a time |
| 10 | The hub decided on its own that only active pool patients are used for seeding (SPEC §6) | Fewer inactive patients in the demo | No rule for which decisions the hub may make on its own |

## Lessons for the next project

1. **Answer scope questions before starting sessions.** If a word has two meanings (district or subdistrict), answer it first; a session started on a guess costs a redo.
2. **Name one owner per shared file from day one.** Set up the hub before starting any side session, not midway.
3. **Gather inputs before generating data.** Settle the glossary, field names, assets and ranges, then generate once.
4. **Freeze decisions before design.** Questions, then Figma, then building. A change after Figma should be a deliberate choice.
5. **Check the environment before the build.** The `gh` account and scopes (including `workflow`), Simulator access, platform licences and package versions; about 5 minutes.
6. **Approve in batches.** At build start, approve the plan's steps together (start streams, Simulator checks, merge after a passing check), and agree which product decisions the hub may make on its own.
7. **Stack fewer PRs.** Merge the first PR as soon as it passes, so the rest don't queue behind it.

## Reusable assets

- **`/build-timeline` skill:** a dependency Gantt page for any GitHub repo (`exports/build-timeline-skill.zip`).
- **The workflow:** spec questions → glossary → Figma → issues with "Blocked by" → a hub plus parallel streams → a timeline.
- **Building blocks:** the geo helpers (`spikes/map_geo/lib/geo/`: point-in-area, nearest road), the deterministic data generator, and the design-token check.

## Known gaps in this review

- Built from the main session's view. Workers' build failures and retries may be missing or underweighted.
- The cost in tokens and in user attention is not measured.
- The end-to-end walkthrough (#27) is still pending.
