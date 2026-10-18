# Money Manager — Design System

Every screen follows this file. Platforms: Android phones and web (Chrome desktop and mobile). Light and dark themes. Never stretch content across a wide screen.

## Direction
Calm, trustworthy and quick. The memorable element is the money itself: big, clear, tabular numbers. Everything else stays quiet. Colors come from the Congolese flag, used with restraint: a river blue as the brand color, gold only for highlights and warnings, red only for expenses and errors.

## Color tokens (define once in `lib/app/theme.dart` as a ColorScheme plus a `MoneyColors` ThemeExtension)
Light: background #F4F6F9, surface #FFFFFF, surfaceMuted #E9EDF3, text #111827, textMuted #5B6575, outline #D5DBE4, primary #0F5FA8 (river blue), onPrimary #FFFFFF, accent #E8B019 (gold), income #1B8A4B, expense #C73E2E, warning #C98A00.
Dark: background #0E1319, surface #161D26, surfaceMuted #1F2833, text #EEF2F7, textMuted #9AA6B6, outline #2B3644, primary #5AA2E6, onPrimary #08233F, accent #F0BE3A, income #4CC27F, expense #F0786A, warning #E0A82E.
Rules: no gradients, no heavy shadows (light: 1px outline; dark: 1px outline, no shadow). Every text/background pair must reach WCAG AA contrast. Never use color alone to carry meaning (income/expense also get a + or - sign).

## Typography
Material 3 type scale with the default font. Amounts always use tabular figures (`FontFeature.tabularFigures()`). Scale: display 40/700 for the main balance, headline 28/700, title 20/600, body 16/400, label 14/500, caption 12/400. Sentence case everywhere, no ALL CAPS labels. Line length under 70 characters.

## Spacing and shape
8-pt grid (4, 8, 12, 16, 24, 32, 48). Card radius 16, input radius 12, button radius 12, chips fully rounded. Buttons are at least 52 high, tap targets at least 48x48. Screen padding 16 on phones, 24 on wide screens.

## Responsive layout (required)
Create `ResponsiveBody` (center + max width + padding) and use it on EVERY screen:
- Phone (under 600 wide): full width, 16 padding.
- Tablet and web (600 and above): content centered, max width 720 (lists, forms, settings); auth and setup forms max width 440.
- Wide web (900 and above): Home uses two columns (balances and summary on the left, recent transactions and alerts on the right), max width 1040.
Navigation shell (`AppShell`, built with Home in M4): bottom `NavigationBar` under 840 wide, `NavigationRail` at 840 and above. Destinations: Home, Transactions, Budgets, Charts, Settings. Convert and Report are quick actions on Home and inside Settings. Modal sheets become centered dialogs (max width 480) on wide screens. Keyboard: Enter submits forms, Tab order follows the screen, visible focus rings.

## Shared widgets (lib/app/widgets/)
`ResponsiveBody`, `AppCard`, `PrimaryButton` (shows a spinner and disables while busy), `SecondaryButton`, `AppTextField` (outlined, label above, helper/error text, password show/hide, autofill hints), `AmountText` (tabular, signed, colored for income/expense), `EmptyState` (icon + one sentence + one action), `ErrorBanner` (what went wrong + how to fix it, never vague), `SectionHeader`.

## Auth screens (sign in, sign up, reset password)
- Phone: top block with the app mark and name "Money Manager" and the line "Track CDF and USD in one place." on the primary color (solid), rounded bottom corners; below it the form on the surface, scrollable, keyboard-safe.
- Wide screens (840 and above): two panels. Left: solid primary panel with the app name, the line above, and three short points (Works offline, CDF and USD wallets, Private PIN lock). Right: the form centered, max width 440.
- Sign in: Email, Password (show/hide), "Forgot password?" text button aligned right, big "Sign in" button, a divider with "or", and "Create an account" as a secondary button. (Google button stays hidden, code kept.)
- Sign up: Email, Password with a clear rule ("At least 6 characters"), Confirm password, "Create account" button, "I already have an account" link.
- Reset: Email, "Send reset link", plain confirmation text after sending ("Check your inbox. If the email has an account, a link is on its way.").
- Errors appear in an `ErrorBanner` above the button, plain language ("Wrong email or password."). Buttons show a spinner while busy. Enter submits. Use `AutofillGroup` and autofill hints. All three screens share one layout widget `AuthLayout`.
- Routes must match exactly: use named constants in `lib/app/routes.dart` for every route and use only those constants in `context.go/push`. A mismatch between a pushed path and a registered path is a bug.

## First-run setup screen
Same centered card style. Title "Set up your wallets". Three fields with plain labels and helper text: "Today's rate (1 USD = ? CDF)", "Money you have in CDF", "Money you have in USD". Live preview line under the fields: "$100 = 280,000 FC at this rate". Button "Start tracking".

## Other screens (apply when building them)
- Home: main balance in display type, wallet cards (CDF, USD) with `AmountText`, month income/expense/net as three small stat tiles, budget alerts as a gold-outlined card, recent transactions list, FAB "Add" on phones, an "Add transaction" button in the header on wide screens.
- Lists: 56-high rows, leading category circle, title, muted subtitle, trailing amount. Swipe to delete only on touch. Add visible hover state and a delete icon on web.
- Forms and sheets: one primary action at the bottom, labels above fields, validation text under the field.
- Charts: use token colors, label values directly, no 3D, no legends that need color matching alone.
- Every list and chart has an `EmptyState`; every async screen has a loading state (not a blank screen) and an `ErrorBanner` with a retry.
- Motion: only short (150-250 ms) transitions that answer an action (sheet open, snackbar). Respect reduced motion.

## Writing
Active, plain words in sentence case. Buttons say what they do ("Save changes", "Add transaction", "Sign in"). Errors say what happened and what to do. Empty states invite one action ("No transactions yet. Add your first one.").

## Checklist before a task is done
- [ ] Looks right at 360 px phone width and at 1280 px web width, light and dark
- [ ] Nothing stretches edge to edge on wide screens
- [ ] Uses tokens and shared widgets, no hard-coded colors or sizes in screens
- [ ] Loading, empty and error states exist
- [ ] Amount text uses tabular figures
