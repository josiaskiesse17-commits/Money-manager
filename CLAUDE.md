# CLAUDE.md

@AGENTS.md
@.docs/plan.md

## Claude-specific notes
- Start each session by reading `.docs/BACKLOG.md` and continuing from the first unchecked task.
- Keep summaries short: what changed and how the user can verify it on the phone.
- Plan before large changes (new feature, data-model change). For small fixes, just do them.
- If a task needs a decision not covered in `plan.md`, ask one clear question instead of guessing.
- After editing Dart files run `dart format .` and `flutter analyze`; run `flutter test` when logic changed.
- Money logic (rounding, conversion, balances) always gets unit tests before moving on.
- Do not add packages beyond those in `plan.md` without asking.
- The user is a software engineering student building this to learn: briefly explain non-obvious choices (offline writes, integer money, security rules).
- On Windows, the user's shell is PowerShell. Give PowerShell commands, not bash.
