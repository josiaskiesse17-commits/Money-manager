# AGENTS.md

Instructions for AI coding agents working in this repo.

## Project
Money Manager: personal Flutter app (CDF + USD wallets, Firebase backend). Read `.docs/plan.md` for scope, data model and rules, and `.docs/BACKLOG.md` for what to work on next.

## Workflow
1. Take the next unchecked task in `.docs/BACKLOG.md`, top to bottom. One task at a time.
2. Keep changes focused. Do not add features outside `plan.md`.
3. When a task is done: run the checks below, tick it in `BACKLOG.md`, and commit.
4. If `plan.md` is unclear or must change, stop and ask one clear question, then update `plan.md`.
5. When a step needs something only the user can do (Firebase console, SHA-1, publishing rules, testing on the phone), stop, tell them exactly what to do, and wait.

## Commands
- Install: `flutter pub get`
- Run: `flutter run`
- Analyze: `flutter analyze`
- Format: `dart format .`
- Test: `flutter test`

A task is done only when `dart format .`, `flutter analyze` (zero issues) and `flutter test` pass.

## Structure
```
lib/
  main.dart
  app/            app.dart, router.dart, theme.dart, auth_gate.dart, app_lock_gate.dart, error_reporter.dart
  core/           money/ (money.dart, currency.dart), constants/
  data/           firebase_providers.dart, balance_delta.dart, models/, repositories/
  features/       auth, onboarding, home, transactions, convert, budgets, charts, reports, settings
                  (each: presentation/ for widgets, application/ for providers and logic)
test/             mirrors lib/, one test file per logic file
```
Firestore is accessed only through `data/` repositories, never from widgets.

## Code rules
- Never use `double` for money. Use the `Money` helper (integer minor units), see `plan.md` "Money rules".
- Store `rateAtEntry` on every transaction; never recalculate old transactions.
- Wallet-to-wallet conversions are not income/expense; exclude them from budgets, charts and totals.
- Balance changes: `WriteBatch` + `FieldValue.increment`. Never `runTransaction` for balances.
- Writes in controllers are fire-and-forget (`unawaited(...)` with error handling), because offline futures only finish when the server answers.
- Categories are archived, never deleted.
- Use `const` where possible, small widgets, no business logic in `build()`.
- Colors and text styles come from the theme; both light and dark must look right.
- Every screen handles loading, error and empty states.
- Imports: use `import 'package:flutter/foundation.dart' show debugPrint;` (or `kDebugMode`) instead of the whole library, because Flutter's `Category` annotation clashes with our `Category` model.
- Do not log financial data or tokens. Use the shared `reportError` helper, not `print` or bare `debugPrint`.
- Test files must always contain a `main()` (an empty placeholder file breaks `flutter test`).
- Lint: prefer `(_, _)` over `(_, __)` for unused parameters.

## Security
- Never commit secrets. Do not paste `google-services.json` contents anywhere. Check `.gitignore` decisions with the user.
- Firestore rules in `firestore.rules` must restrict all data to the signed-in owner (see `plan.md`).
- The app-lock PIN is only a salted hash in secure storage; never store it in plain text or in Firebase.

## Web notes
- Hide the biometrics option on web (`local_auth` is unavailable).
- On web the PIN is stored in browser storage and is less secure than on Android.
- Firestore offline persistence works on web only in one tab.
- PDF share downloads the file on web.
- Never crash when a plugin isn't supported on web: wrap plugin calls (e.g. `local_auth`) in try/catch.

## Git
- Small commits with clear messages (`feat:`, `fix:`, `test:`, `chore:`), one backlog task per commit when practical.
