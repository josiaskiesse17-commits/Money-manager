# Money Manager — v1 Plan

Personal money management app in Flutter. One user, two currencies (CDF and USD), works offline, minimal and fast to use. This file is the source of truth for scope and design. If a decision changes, update this file.

- Project name: `money_manager`. Android package: `com.namegmail.money_manager`.
- Android first. Keep the code platform-neutral so iOS can be added later.

## Goals
- Add an income/expense in about 2 taps from Home.
- Two wallets (CDF, USD) with a convert action between them.
- Per-category monthly budgets, basic charts, printable PDF report.
- Works offline; syncs when online.

## Out of scope for v1
Google sign-in (code stays ready, UI hidden), savings goals, bill reminders, recurring transactions, CSV export, bank/mobile-money import, multi-user sharing.

## Stack
Flutter (stable), Dart null-safety. Firebase Auth (email/password) + Cloud Firestore with offline persistence on. Riverpod (state), go_router (navigation), fl_chart (charts), `pdf` + `printing` (reports), `local_auth` + `flutter_secure_storage` + `crypto` (app lock), `intl` (formatting), `google_sign_in` (kept for later).

## Money rules (critical)
- Never use `double` for money. Store integers in minor units.
- USD minor unit = cent (2 decimals). CDF minor unit = 1 franc (0 decimals).
- Exchange rate = CDF per 1 USD, stored as an integer scaled by 100 (2800.50 -> 280050). Parsing accepts up to 2 decimals and "," or ".".
- Conversion uses integer math, rounded half away from zero, in one shared `Money` helper:
  - USD cents -> CDF francs: `cents * rateScaled / 10000`
  - CDF francs -> USD cents: `francs * 10000 / rateScaled`
- Every transaction stores `rateAtEntry` (rate when it was entered). Old transactions are never recalculated when the rate changes. Edits keep the original `rateAtEntry`.
- Totals mixing currencies convert each transaction with its own `rateAtEntry`. Total wallet balance uses the current rate from settings.
- Converting between wallets is NOT income or expense. Exclude it from budgets, charts, summaries and PDF totals.
- `Money` must have unit tests: parse (incl. rejecting decimals for CDF), format (`$1,234.50`, `35,000 FC`, negatives), convertTo both ways, rounding of exact halves, add/subtract, currency mismatch error.

## Data model (Firestore, all under `users/{uid}`)
- `settings/main`: `usdToCdfRate` (int x100), `theme` (light|dark|system), `displayMode` (cdf|usd|combined), `onboarded` (bool)
- `wallets/{CDF|USD}`: `currency`, `openingBalance`, `balance` (maintained by increments)
- `categories/{id}`: `name`, `icon` (key), `color` (ARGB int), `type` (income|expense), `archived`
- `transactions/{id}`: `amount` (int > 0), `currency`, `type`, `categoryId`, `date` (Timestamp), `note`, `rateAtEntry`, `createdAt`, `updatedAt`
- `conversions/{id}`: `fromCurrency`, `toCurrency`, `fromAmount`, `toAmount`, `rate`, `date`
- `budgets/{categoryId}`: `categoryId`, `currency`, `monthlyLimit` (one budget per category; doc id = categoryId)

Balance maintenance: wallet `balance` changes with `FieldValue.increment` inside a `WriteBatch` together with the document write (set with merge). Never use `runTransaction` for balances (fails offline). Pure function `balanceDeltas(before, after)` computes the change: add (before null), delete (after null), edit (both; difference only; handles type or currency changes). Unit test it.

Queries: only a date range is queried in Firestore (no composite indexes). Category, wallet and note filters run in memory.

## Screens
1. **Auth**: email/password sign in, sign up, password reset. `AuthRepository` keeps `signInWithGoogle()` (Firebase `signInWithProvider(GoogleAuthProvider())`) but the button is commented out.
2. **AuthGate** (above everything): loading -> sign-in -> first-run setup -> Home.
3. **First-run setup**: rate (required, no default), opening balance for CDF (whole francs) and USD. Seeds default categories. Writes are fire-and-forget (offline-safe).
4. **Home**: month bar, display toggle CDF / USD / Both (saved in settings), wallet balances (+ total when CDF or USD selected), month income/expense/net, budget alerts, 5 recent transactions, FAB "+", shortcuts to Budgets, Charts, Convert, Report, Settings.
5. **Add/Edit transaction** (modal bottom sheet): expense/income, wallet (CDF/USD), amount keypad (CDF no decimal key, USD max 2 decimals, max 12 digits), category chips (only matching type, archived hidden unless selected), date (default today), note (max 200). Edit shows delete.
6. **Transactions list**: month navigation, search note, filters (category, wallet, date range which replaces the month), swipe to delete with Undo (Undo rewrites the same doc id), tap to edit.
7. **Convert**: direction USD->CDF or CDF->USD, amount, rate prefilled from settings (editable for this conversion only), live preview, history with delete (reverses balances).
8. **Budgets**: one budget per expense category, each in CDF or USD, progress bar for the selected month. Spending counts only expenses in the budget's own category AND currency, no conversion. Levels with integer math: warning from 80% of limit, exceeded from 100%. Home shows alerts for warning/exceeded.
9. **Charts**: donut of spending by category + bars of daily spending, for the selected month, in chosen currency (converted with each `rateAtEntry`). Expenses only.
10. **Report**: This month / Last month / Custom range -> PDF (A4): period, totals per wallet, full transaction list oldest first, no charts, footer note that conversions are excluded. Preview/Print and Share.
11. **Settings**: exchange rate, categories (add, edit, archive/restore; never delete), theme (light/dark/system, saved in settings), app lock, sign out.
12. **App lock**: 4-digit PIN stored as salted SHA-256 hash in secure storage (device only), optional biometrics, locks at app start and after 15 s in background. Lock screen sits above the Navigator (via `MaterialApp.builder`) using `Offstage` so app state survives. "Forgot PIN" signs out and removes the lock.

## Default categories
Expense: Food, Transport, Rent, Airtime & Internet, Utilities, Health, Education, Shopping, Family, Other. Income: Salary, Business, Gift, Other. Fixed ids so seeding twice is safe.

## Errors
Create one `reportError(Object, {String? userMessage})` helper: logs only in debug (`kDebugMode`), and shows a short snackbar via a global `ScaffoldMessenger` key for real failures (e.g. permission denied). Offline is not an error (Firestore queues writes). Controllers call it instead of printing.

## Firestore security rules (publish in the Firebase console, also keep in `firestore.rules`)
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isOwner(uid) { return request.auth != null && request.auth.uid == uid; }
    function validCurrency(c) { return c in ['CDF', 'USD']; }
    function positiveInt(v) { return v is int && v > 0; }

    match /users/{uid}/settings/{docId} {
      allow read: if isOwner(uid);
      allow create, update: if isOwner(uid) && positiveInt(request.resource.data.usdToCdfRate);
    }
    match /users/{uid}/wallets/{currency} {
      allow read: if isOwner(uid);
      allow create, update: if isOwner(uid) && validCurrency(currency) && request.resource.data.balance is int;
    }
    match /users/{uid}/categories/{id} {
      allow read: if isOwner(uid);
      allow create, update: if isOwner(uid)
        && request.resource.data.name is string
        && request.resource.data.name.size() > 0 && request.resource.data.name.size() <= 40
        && request.resource.data.type in ['income', 'expense']
        && request.resource.data.color is int;
    }
    match /users/{uid}/transactions/{id} {
      allow read, delete: if isOwner(uid);
      allow create, update: if isOwner(uid)
        && positiveInt(request.resource.data.amount)
        && validCurrency(request.resource.data.currency)
        && request.resource.data.type in ['income', 'expense']
        && request.resource.data.categoryId is string
        && positiveInt(request.resource.data.rateAtEntry)
        && request.resource.data.date is timestamp
        && request.resource.data.note is string && request.resource.data.note.size() <= 500;
    }
    match /users/{uid}/conversions/{id} {
      allow read, delete: if isOwner(uid);
      allow create: if isOwner(uid)
        && positiveInt(request.resource.data.fromAmount)
        && request.resource.data.toAmount is int && request.resource.data.toAmount >= 0
        && validCurrency(request.resource.data.fromCurrency)
        && validCurrency(request.resource.data.toCurrency)
        && request.resource.data.fromCurrency != request.resource.data.toCurrency
        && positiveInt(request.resource.data.rate);
    }
    match /users/{uid}/budgets/{id} {
      allow read, delete: if isOwner(uid);
      allow create, update: if isOwner(uid)
        && positiveInt(request.resource.data.monthlyLimit)
        && validCurrency(request.resource.data.currency)
        && request.resource.data.categoryId is string;
    }
  }
}
```
Anything not listed is denied.

## Tests expected
`Money`/`ExchangeRate`; model round trip; `balanceDeltas`; keypad logic; transaction filters; home totals (own-rate conversion); budget math (80%/100% boundaries, same category and currency only); chart data; PIN hashing; PDF generation (bytes start with `%PDF`).
