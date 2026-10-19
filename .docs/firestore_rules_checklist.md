# Firestore Rules Checklist

## All Firestore Write Paths

| Path | Operation | Fields | Rule Match | Rule Condition | Compliant |
|------|-----------|--------|------------|----------------|-----------|
| `users/{uid}/settings/main` | create, update | `usdToCdfRate` (int), `theme` (string), `displayMode` (string), `onboarded` (bool) | `match /users/{uid}/settings/{docId}` | `isOwner(uid) && positiveInt(usdToCdfRate)` | YES |
| `users/{uid}/wallets/{currency}` | create, update | `currency` (string), `openingBalance` (int), `balance` (int) | `match /users/{uid}/wallets/{currency}` | `isOwner(uid) && validCurrency(currency) && balance is int` | YES |
| `users/{uid}/categories/{id}` | create, update | `name` (string), `icon` (string), `color` (int), `type` (income\|expense), `archived` (bool) | `match /users/{uid}/categories/{id}` | `isOwner(uid) && name is string && name.size() > 0 && name.size() <= 40 && type in ['income','expense'] && color is int` | YES |
| `users/{uid}/transactions/{id}` | create, update | `amount` (int>0), `currency` (string), `type` (income\|expense), `categoryId` (string), `date` (timestamp), `note` (string<=500), `rateAtEntry` (int>0), `createdAt` (timestamp), `updatedAt` (timestamp) | `match /users/{uid}/transactions/{id}` | `isOwner(uid) && positiveInt(amount) && validCurrency(currency) && type in ['income','expense'] && categoryId is string && positiveInt(rateAtEntry) && date is timestamp && note is string && note.size() <= 500` | YES |
| `users/{uid}/transactions/{id}` | delete | (none — doc delete) | `match /users/{uid}/transactions/{id}` | `isOwner(uid)` | YES |
| `users/{uid}/conversions/{id}` | create | `fromCurrency` (string), `toCurrency` (string), `fromAmount` (int>0), `toAmount` (int>=0), `rate` (int>0), `date` (timestamp) | `match /users/{uid}/conversions/{id}` | `isOwner(uid) && positiveInt(fromAmount) && toAmount is int && toAmount >= 0 && validCurrency(fromCurrency) && validCurrency(toCurrency) && fromCurrency != toCurrency && positiveInt(rate)` | YES |
| `users/{uid}/conversions/{id}` | delete | (none — doc delete) | `match /users/{uid}/conversions/{id}` | `isOwner(uid)` | YES |
| `users/{uid}/budgets/{id}` | create, update | `categoryId` (string), `currency` (string), `monthlyLimit` (int>0) | `match /users/{uid}/budgets/{id}` | `isOwner(uid) && positiveInt(monthlyLimit) && validCurrency(currency) && categoryId is string` | YES |
| `users/{uid}/budgets/{id}` | delete | (none — doc delete) | `match /users/{uid}/budgets/{id}` | `isOwner(uid)` | YES |

## Balance Maintenance (FieldValue.increment)

All balance changes use `WriteBatch` with `FieldValue.increment(delta)` — never `runTransaction`:

- `transaction_repository.dart:addTransaction` — updates wallet balance via batch
- `transaction_repository.dart:updateTransaction` — updates wallet balance via batch
- `transaction_repository.dart:deleteTransaction` — updates wallet balance via batch
- `conversion_repository.dart:addConversion` — updates both wallet balances via batch
- `conversion_repository.dart:deleteConversion` — updates both wallet balances via batch

## Repository Write Paths vs Rules

| Repository | Method | Firestore Path | Rule Validates |
|------------|--------|---------------|----------------|
| `settings_repository.dart` | `saveSettings` | `users/{uid}/settings/main` | `usdToCdfRate` positive int |
| `wallet_repository.dart` | `updateBalance` | `users/{uid}/wallets/{currency}` | `balance is int`, valid currency |
| `category_repository.dart` | `saveCategory` | `users/{uid}/categories/{id}` | name, type, color validated |
| `category_repository.dart` | `archiveCategory` | `users/{uid}/categories/{id}` | (update — same rule) |
| `transaction_repository.dart` | `addTransaction` | `users/{uid}/transactions/{id}` + wallet balance | all txn fields validated |
| `transaction_repository.dart` | `updateTransaction` | `users/{uid}/transactions/{id}` + wallet balance | all txn fields validated |
| `transaction_repository.dart` | `deleteTransaction` | `users/{uid}/transactions/{id}` (delete) | owner only |
| `conversion_repository.dart` | `addConversion` | `users/{uid}/conversions/{id}` + wallet balances | all conversion fields validated |
| `conversion_repository.dart` | `deleteConversion` | `users/{uid}/conversions/{id}` (delete) | owner only |
| `budget_repository.dart` | `saveBudget` | `users/{uid}/budgets/{id}` | monthlyLimit positive int, valid currency, categoryId string |

## Notes

- All reads are restricted to `isOwner(uid)` — user can only read their own data.
- Anything not listed in the rules is denied by default.
- Wallet balance updates via `FieldValue.increment` inside `WriteBatch` do not write full documents — they update individual fields. The rules validate the full document on create/update, but increment updates only touch the `balance` field.
- `rateAtEntry` is stored on every transaction at creation time and never recalculated.
- Wallet-to-wallet conversions are excluded from budgets, charts, and totals (not income/expense).
