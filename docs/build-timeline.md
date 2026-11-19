# Build timeline skill (`/build-timeline`)

A Claude Code skill, made during this project, that publishes a Gantt-style **build timeline** of a GitHub repo's issues and PRs as one private Claude Artifact page, and refreshes it on demand or on a loop.

## What the page shows

- Issues grouped into **streams** on a real time axis (issue opened → PR opened → merged).
- A **git lane** with the PR stack.
- **"Blocked by" lines** between issues; an issue that blocks 8 or more others shows its links only when its row is tapped.
- **Planned order after "now"** for open issues, in fixed slots (`slotMinutes`, default 10). These bars show order only, not a date estimate.
- A zoom bar under the chart and a resizable title column.

States come from GitHub: **done** = issue closed or PR merged; **in review** = PR open; otherwise **ready** (all blockers done) or **blocked**. GitHub has no "in progress", so nothing shows as started before a PR exists.

## Install

The skill lives at `~/.claude/skills/build-timeline/` on the machine where it was made. To share it, use the packaged copy `exports/build-timeline-skill.zip`. It's ignored by git, so it isn't in this repo; ask the repo owner for it.

```bash
unzip build-timeline-skill.zip -d ~/.claude/skills/
```

Start a new Claude Code session afterwards: skills load when a session starts.

Requirements: Claude Code with the Artifact tool (claude.ai account), `gh` signed in with read access to the repo, `python3` (standard library only) and `git`.

## Use

In the repository folder, in a Claude Code session:

```
/build-timeline
```

The first run publishes a new private page and saves its link as `artifactUrl` in the project config. Later runs regenerate the data and update the same page. To refresh every 15 minutes while the session stays open:

```
/loop 15m /build-timeline
```

On a loop tick where nothing changed, the skill reports nothing and doesn't republish.

The generator only reads: `gh` and `git fetch`. It never pulls, commits or changes the checkout, so it's safe in a folder that other sessions share. To run it by hand:

```bash
python3 -I ~/.claude/skills/build-timeline/gen_timeline.py "$PWD" /tmp/build-timeline
```

It writes `index.html` and `data.json` to the output folder and prints the config path, the artifact URL (or "none yet") and a count line.

## What it needs on GitHub

| The page shows | Needs this |
|---|---|
| Which PR belongs to which issue | `Closes #N` (or Fixes / Resolves) in the PR description |
| Dependency lines | A line `Blocked by: #A, #B` in the issue description, the shape the `to-tickets` skill writes and that issues #1–#28 here use |
| Streams | A `streams` list in the project config, or GitHub milestones |

PRs with no `Closes #N` appear under "Pull requests without an issue". In this repo those are the hub's cleanup (#64) and the post-walkthrough fixes (#54, #58, #63, #65–#68, #70).

## Project config

The first match wins:

1. `docs/agents/timeline.json` in the repo
2. `~/.claude/skills/build-timeline/projects/<owner>__<repo>.json` (for this repo: `jedt3d__BedRiddenPt.json`)

All keys are optional: `project` (page title), `timezone` (IANA, e.g. `Asia/Bangkok`; the default is the computer's zone), `streams` (`[{id, name, issues: [n…]}]`), `slotMinutes`, and `artifactUrl` (written by the first run). Start from `projects/example.json` in the skill folder.

This repo's config lives in the user's skill folder, not in the repo, so the private page link isn't published. Its streams match [STATUS.md](STATUS.md): A Foundation (#1 #2 #3 #28 #4–#7), B1 Launch (#8–#10), B2 List (#11–#14), B3 Map (#15 #16 #18 #17), B4 Detail (#19 #20), C Form (#21–#24), D Location + photo (#25 #26), E Walkthrough (#27). The config keeps C and D as separate groups, although one worker session built both.

## Privacy

The page is private to whoever publishes it until it's shared from the page's Share menu.
