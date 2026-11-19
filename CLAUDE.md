# BedRiddenPt

Flutter prototype for recording bedridden patients in Khlong San district, Bangkok. The spec is `SPEC.md`.

## Agent skills

### Issue tracker

GitHub Issues via the `gh` CLI on `jedt3d/BedRiddenPt` (public). See `docs/agents/issue-tracker.md`.

### Triage labels

The five default labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root, created when first needed. See `docs/agents/domain.md`.

## Design tokens

Every colour, spacing, radius and text style in `lib/` comes from `lib/theme/tokens.dart`.

- `lib/theme/tokens.dart` (`AppColors`, `AppSpace`, `AppRadius`, `AppText`) is generated from `design/tokens.json` (the Figma variables export) by `dart run tool/gen_tokens.dart`. Don't edit it by hand. When the Figma tokens change: re-export, review the diff of `design/tokens.json`, regenerate, commit both.
- `tool/check_tokens.sh` fails on `Color(0x…)`, `Colors.`, `CupertinoColors.`, a numeric `fontSize:`, or numeric `EdgeInsets` / `BorderRadius` / `Radius.circular` values in `lib/` outside `lib/theme/`. It runs in CI, in the Claude Code Stop hook (`.claude/settings.json`) and in the git pre-commit hook; enable that once per clone with `git config core.hooksPath tool/hooks`.
- Font: the system font (SF Pro on iOS). Inter in Figma is only a stand-in.
