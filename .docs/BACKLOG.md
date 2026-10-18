# BACKLOG

Work top to bottom. Tick a task only when `dart format .`, `flutter analyze` and `flutter test` pass. Tasks marked (USER) need the user: stop and give exact steps.

## M0 — Setup
- [x] Create or open the Flutter project `money_manager` (org `com.namegmail`), add the packages from `plan.md`, create the folder structure from `AGENTS.md`
- [x] (USER) Firebase: create project, enable Email/Password, create Firestore (Standard edition, production mode), run `flutterfire configure`, set Android `minSdk` to at least 23
- [x] `main.dart` (Firebase init, Firestore offline persistence on), app theme light/dark, router skeleton, shared `reportError` helper with global ScaffoldMessenger key

## M1 — Core logic
- [x] `Currency`, `Money`, `ExchangeRate` + unit tests (see `plan.md` money rules)
- [x] Models: settings, wallet, category, transaction, conversion, budget (+ round-trip test)
- [x] `balanceDeltas` + tests
- [x] Repositories and Riverpod providers (auth, settings, wallets, categories, transactions, conversions, budgets)
- [x] `firestore.rules` from `plan.md` (USER publishes it in the Firebase console)

## M2 — Auth and onboarding
- [x] Sign in, sign up, reset password screens; Google method stays in `AuthRepository`, button commented out
- [x] `AuthGate` and first-run setup (rate, opening balances, seed default categories)

## M3 — Transactions
- [ ] Add/edit sheet with amount keypad (+ keypad tests) and category chips
- [ ] Controller: add, edit (keeps `rateAtEntry`), delete, undo; balances via batch increments
- [ ] Transactions list with month navigation, search and filters (+ filter tests)

## M4 — Home and convert
- [ ] Home: balances, display toggle, month summary (+ summary tests), recent list, FAB
- [ ] Convert screen with preview and history/delete

## M5 — Budgets and charts
- [ ] Budgets screen and dialog, budget math (+ boundary tests), alerts on Home
- [ ] Charts: donut and daily bars (+ data tests)

## M6 — Reports, settings, lock
- [ ] PDF report service (+ `%PDF` test) and Report screen (preview/print, share)
- [ ] Settings: rate, categories (add/edit/archive), theme saved in settings
- [ ] App lock: PIN (salted hash), biometrics, lock gate, PIN setup, forgot-PIN flow (+ hashing test). Android: `USE_BIOMETRIC` permission and `FlutterFragmentActivity`

## M7 — Polish and release
- [ ] Empty/error/loading states everywhere; app icon and splash
- [ ] (USER) Manual pass: offline and online, both themes, both currencies, edit/delete balance checks, run on Chrome (`flutter run -d chrome`) and on a phone
- [ ] Release build (APK/AAB) and check the `INTERNET` permission in the main manifest

## Later (v2)
Google sign-in (uncomment button, SHA-1, `flutterfire configure`), savings goals, bill reminders, recurring transactions, CSV export.
