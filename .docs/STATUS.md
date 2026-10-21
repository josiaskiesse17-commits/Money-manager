# Project Status — Money Manager

_Generated from a code review of the repository plus a fresh run of `flutter analyze`, `dart format --set-exit-if-changed` and `flutter test`. All statements below are backed by files in this repo or by the commands listed in "Verification evidence"._

Date: 2026-10-21
Branch: `main` @ `7bc2b2d` ("fixing layout issues"), tracking `origin/main`

---

## 1. Executive summary

The app is **functionally broad but not release-ready**. All planned features (M0–M6) are implemented in code and the vast majority of the test suite passes (**195 of 210 tests pass**), but the project currently fails its own definition of done:

- `flutter analyze` → **4 issues** (3 warnings, 1 info) — the AGENTS.md bar is *zero issues*.
- `dart format --set-exit-if-changed .` → **12 files would be reformatted** (exit code 1).
- `flutter test` → **15 failing tests**, all in the widget/layout layer, all caused by `RenderFlex` overflows.

The failures are concentrated in one theme: **responsive layout overflows** in `AppShell` (Settings, Transactions), the Settings screen itself, and long transaction lists. Two of them are in a shared widget (`lib/app/widgets/primary_button.dart:43`), so fixing them fixes several tests at once.

Because the last three BACKLOG tasks in M7 depend on a clean build and a manual pass on a real device, M7 is **not started**.

---

## 2. Verification evidence

| Check | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze` | **4 issues** (exit 1) |
| Formatting | `dart format --output=none --set-exit-if-changed .` | **12 of 86 files changed** (exit 1) |
| Tests | `flutter test` | **195 passed, 15 failed** (exit 1) |
| Git state | `git status --porcelain` | 1 modified file, 3 untracked files (see §6) |

Raw logs kept in the repo: `.docs/analyze_out.txt`, `.docs/test_status_full.txt`.

### 2.1 Analyzer issues (exact)

```
info    use_build_context_synchronously  lib/features/settings/presentation/settings_screen.dart:857:28
warning unused_import                     lib/features/transactions/presentation/add_edit_transaction_sheet.dart:11  (app/widgets/secondary_button.dart)
warning unused_import                     lib/features/transactions/presentation/add_edit_transaction_sheet.dart:12  (app/widgets/section_header.dart)
warning unused_local_variable             lib/features/transactions/presentation/add_edit_transaction_sheet.dart:265 (screenHeight)
```

### 2.2 Failing tests (exact, 15)

All in `test/widget_tests/`:

| File | Test |
|---|---|
| `layout_test.dart` | AppShell layout — Settings in AppShell at 300x800 without overflow |
| `layout_test.dart` | AppShell layout — Settings in AppShell at 360x800 without overflow |
| `layout_test.dart` | AppShell layout — Transactions in AppShell at 300x800 without overflow |
| `layout_test.dart` | AppShell layout — Transactions in AppShell at 360x800 without overflow |
| `layout_test.dart` | Transactions — renders at 360x800 without overflow |
| `layout_test.dart` | Transactions 100 items — renders 100 transactions at 360.0x800.0 without overflow |
| `layout_test.dart` | Transactions 100 items — renders 100 transactions at 1280.0x800.0 without overflow |
| `settings_screen_test.dart` | SettingsScreen renders phone light without overflow |
| `settings_screen_test.dart` | SettingsScreen renders phone dark without overflow |
| `settings_screen_test.dart` | SettingsScreen signing out … phone light / phone dark / web light / web dark |
| `settings_screen_test.dart` | SettingsScreen tapping Add category opens the category dialog — phone light / phone dark |

Overflow magnitudes seen in the logs: 49, 50, 58, 110 px on the right; 8, 129, 238 px on the bottom.

**Dominant root cause:** `lib/app/widgets/primary_button.dart:43` — a horizontal `Row` inside the shared button overflows on narrow widths (58 px / 50 px on the right). The vertical overflows (129 px, 238 px) come from `Row` layouts in the settings/transaction screens that do not wrap or scroll.


## 3. Milestone status (from `.docs/plan.md` / `.docs/BACKLOG.md`)

| Milestone | Scope | Status | Evidence |
|---|---|---|---|
| **M0 — Setup** | project, packages, folder structure, Firebase, `main.dart`, theme, router, `reportError` | ✅ Complete (ticked) | `lib/main.dart`, `lib/app/{app,router,theme,error_reporter}.dart` |
| **M1 — Core logic** | `Currency`/`Money`/`ExchangeRate`, models, `balanceDeltas`, repositories/providers, `firestore.rules` | ✅ Complete (ticked) | `lib/core/money/`, `lib/data/`, `firestore.rules`; passing `money_test.dart`, `balance_delta_test.dart`, `models_test.dart` |
| **M2 — Auth & onboarding** | sign in/up/reset, `AuthGate`, first-run setup (rate, opening balances, seed categories) | ✅ Complete (ticked) | `lib/features/auth/`, `lib/features/onboarding/presentation/first_run_setup.dart`; `auth_gate_test.dart`, `auth_verification_test.dart`, `verify_email_screen_test.dart` pass |
| **M3 — Transactions** | add/edit sheet + keypad, controller add/edit/delete/undo, list with month nav, search, filters | ⚠️ Code complete, **layout failing** | `lib/features/transactions/`; `transaction_provider_test.dart` passes; **3 layout tests fail** (overflow) |
| **M4 — Home & convert** | balances, display toggle, month summary, recent list, FAB; convert with preview + history/delete | ⚠️ Partially verified | `lib/features/home/`, `lib/features/convert/`; Home wide (900/1280) tests pass, phone width untested here |
| **M5 — Budgets & charts** | budgets screen/dialog, budget math, alerts on Home, donut + daily bar charts | ✅ Code complete, tests pass | `budget_provider_test.dart`, `budget_test.dart` pass; `charts_loading_test.dart` and chart layout tests pass |
| **M6 — Reports, settings, lock** | PDF service + report screen, settings (rate/categories/theme/lock/sign out), PIN lock + biometrics + 15s re-lock, Android permissions, tests | ⚠️ Code complete, **settings layout failing** | `lib/features/reports/`, `lib/features/settings/`, `lib/app/app_lock_gate.dart`; `app_lock_provider_test.dart` (hash + 15 s rule) and `report_test.dart` pass; **10 settings tests fail** |
| **M7 — Polish & release** | empty/error/loading states everywhere, icon & splash, manual pass, release build | ❌ Not started (all three boxes unticked) | `assets/icon/` and `web/` splash exist, but the build is not green and no release build was made |


## 4. Feature-by-feature implementation review

### Present and consistent with `plan.md`
- **Money rules** — integer minor units everywhere; `Money.parse/format/convertTo` centralises rounding; CDF has 0 decimals, USD 2; rate stored scaled ×100. No `double` money in the data layer.
- **Balances** — `lib/data/repositories/transaction_repository.dart` and `conversion_repository.dart` use `WriteBatch` + `FieldValue.increment`; **no `runTransaction`** anywhere. Deletes reverse the balance with the opposite sign.
- **Conversions excluded** — `report_service.dart` writes the footer note "Wallet-to-wallet conversions are excluded from this report."; conversions live in their own collection, not in `transactions`.
- **Firestore rules** — `firestore.rules` restricts every collection under `users/{uid}` to the owner, with positive-int / currency / type validation, matching the rules block in `plan.md`.
- **Responsive scaffolding** — `lib/app/widgets/responsive_body.dart` (phone < 600 → 16 padding, content max 720 / 24 padding), `lib/app/app_shell.dart` (NavigationBar < 840, NavigationRail ≥ 840), `home_screen.dart` two-column layout at ≥ 900 (max width 1040).
- **App lock** — salted SHA-256 in secure storage (`app_lock_provider.dart`: `generateSalt`, `hashPin`, `_saltKey`), 15 s background re-lock enforced (`elapsed.inSeconds >= 15`).
- **Error handling** — shared `reportError` helper, `ErrorBanner` with retry on every async screen.
- **Categories** — archived, not deleted; seeded with fixed ids.
- **Web** — `web/` target present with icons/splash/manifest; `local_auth` guarded.

### Gaps / items needing explicit status
| Area | Finding |
|---|---|
| **Responsive overflow** | The single biggest gap. Shared `primary_button.dart:43` and several screen `Row`s overflow at 300/360 px. Violates the `design.md` checklist for 360 px phone. |
| **FAB on Home** | `home_screen.dart` contains **no** `FloatingActionButton`; the plan's "add income/expense in ~2 taps from Home" and BACKLOG M4 "FAB" are not visibly satisfied from Home. Add is reached only via the Transactions list sheet. |
| **Display toggle on Home** | `plan.md`/BACKLOG M4 ask for a CDF/USD/combined display toggle; Home always renders raw CDF and USD balances side by side. `Setting.displayMode` exists in the model and is used by charts (`charts_screen.dart:83`), but Home does not offer the toggle. |
| **Transaction undo** | `transaction_repository.deleteTransaction` documents "Undo rewrites the same doc id", but **no `restoreTransaction` exists** and nothing calls one. Deletion is permanent via a confirm dialog saying "This action cannot be undone." BACKLOG M3 claims "delete, undo". |
| **Routing consistency** | `AppRoutes.addTransaction` / `editTransaction` (`/transactions/add`, `/transactions/edit`) are declared but **never used or registered** in `router.dart`; the add/edit UI is a modal bottom sheet. Dead route constants that contradict the "named route constants everywhere" rule. |
| **Reports/Convert entry points** | `router.dart` registers `/convert` and `/reports`, and both screens use `AppRoutes.*` for their nav highlight, but no visible navigation entry point to either screen was found in Home or the shell. |
| **Home "total"** | Plan mentions a combined total; Home shows per-currency balances and a CDF-only month summary. |
| **Charts rate handling** | `charts_screen.dart` converts USD→CDF with the **current** rate (`setting.usdToCdfRate`), while `plan.md` requires totals to convert each transaction with its own `rateAtEntry`. Spec deviation needing a fix or a documented decision. |
| **Uncommitted work** | `lib/features/settings/presentation/settings_screen.dart` has **342 insertions / 160 deletions** uncommitted in the working tree (shared-button refactor, `OutlinedButton.icon` sign-out, light/dark text colours). It is the file with 6 of the 15 failing tests and one analyzer info. |
| **Stray file** | `test_status_full.txt` sits in the repo root (untracked) in addition to `.docs/test_status_full.txt`. Should be deleted or moved. |

---


## 5. Risk assessment

| Risk | Severity | Notes |
|---|---|---|
| Layout regressions on small phones | **High** | 15 failing tests; two of the bottom-nav screens overflow at 300 px. This is the release blocker. |
| Uncommitted refactor lost | **High** | 502 lines changed in `settings_screen.dart` are not committed; a `git checkout` would discard them. |
| Money-math deviation in charts | **Medium** | Charts use the live rate instead of per-transaction `rateAtEntry`; historical charts shift when the rate changes. |
| Missing undo / FAB / display toggle | **Medium** | Three ticked BACKLOG items are only partially implemented. |
| Release build never attempted | **Medium** | M7 "Release build (APK/AAB) and check `INTERNET` permission" is unticked; `printing`/`pdf` and `flutter_secure_storage` have never been exercised in a release build. |
| Real-device / Chrome manual pass | **Medium** | Never done; biometrics, secure storage and offline persistence untested outside the emulator. |
| Unused dependencies | **Low** | `google_sign_in` is intentionally kept for v2; `collection` is used. No action needed. |

---

## 6. Git state

```
 M lib/features/settings/presentation/settings_screen.dart
?? .docs/analyze_out.txt
?? .docs/test_status_full.txt
?? test_status_full.txt
```

Recent history is a series of layout-fix commits (`7bc2b2d`, `4ca6ed7`, `2936362`, `adc4068`, `2cded82`, `af35b0b`, `b5f78a0`, …) — the overflow problem is being chased and not yet closed.

---

## 7. Recommended next actions (in order)

1. **Fix the shared button overflow** — `lib/app/widgets/primary_button.dart:43`: make the label `Flexible`/`FittedBox`, or let the `Row` wrap. This alone should clear the 58 px / 50 px right-overflow failures.
2. **Fix the vertical overflows** in the Settings screen and the 100-item transaction list (make the offending `Row`s wrap or scroll). Re-run `flutter test test/widget_tests/layout_test.dart test/widget_tests/settings_screen_test.dart`.
3. **Clean the analyzer output** — remove the two unused imports and the unused `screenHeight` in `add_edit_transaction_sheet.dart`; fix the `use_build_context_synchronously` info at `settings_screen.dart:857`.
4. **Run `dart format .`** and commit the result (12 files are currently unformatted).
5. **Commit the pending Settings refactor** (or revert it deliberately) so the tree is clean before further work.
6. **Delete the stray root `test_status_full.txt`** and decide whether `.docs/analyze_out.txt` / `.docs/test_status_full.txt` are committed or ignored.
7. **Reconcile the three functional gaps** with `plan.md`: add a Home FAB, add the display toggle, and either implement transaction undo or amend BACKLOG M3.
8. **Fix or document the charts rate question** (per-transaction `rateAtEntry` vs current rate).
9. **Then run the M7 manual pass** (offline/online, both themes, both currencies, edit/delete balance checks, Chrome and a real phone), and only afterwards the release build.

---

## 8. Explicitly out of scope / not verified

- No real-device or Chrome run was performed; all conclusions come from static reading plus `flutter test`.
- No APK/AAB build was attempted.
- Firestore rules were read but not deployed or tested against a live project.
- The Firebase console tasks marked `(USER)` in BACKLOG M0 were assumed done because the boxes are ticked.
