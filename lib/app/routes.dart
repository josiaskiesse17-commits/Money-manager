/// Named route constants used across the app.
///
/// Every route registration in [router] and every navigation call
/// (`context.go`, `context.push`) must use these constants. A mismatch
/// between a pushed path and a registered path is a bug.
class AppRoutes {
  AppRoutes._();

  static const signIn = '/';
  static const signUp = '/signup';
  static const resetPassword = '/reset-password';
  static const home = '/home';
  static const transactions = '/transactions';
  static const addTransaction = '/transactions/add';
  static const editTransaction = '/transactions/edit';
  static const convert = '/convert';
  static const budgets = '/budgets';
  static const charts = '/charts';
  static const reports = '/reports';
  static const settings = '/settings';
}
