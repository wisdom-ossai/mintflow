import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mintflow formatting utilities — formatters are cached (hot-path safe).
// ─────────────────────────────────────────────────────────────────────────────

class MintflowFormat {
  MintflowFormat._();

  static final NumberFormat _currency =
      NumberFormat('#,##0.00', 'en_US');
  static final DateFormat _date = DateFormat('MMM d, yyyy');
  static final DateFormat _dateShort = DateFormat('MMM d');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');
  static final DateFormat _monthShort = DateFormat('MMM yyyy');
  static final DateFormat _dayOfWeek = DateFormat('EEEE');
  static final DateFormat _time = DateFormat('h:mm a');

  // ── Currency ──────────────────────────────────────────────────────────────

  static String currency(double amount,
      {String symbol = '\$', bool showSign = false}) {
    final formatted = '$symbol${_currency.format(amount.abs())}';
    if (showSign && amount >= 0) return '+$formatted';
    if (amount < 0) return '-$formatted';
    return formatted;
  }

  static String currencyCompact(double amount, {String symbol = '\$'}) {
    if (amount.abs() >= 1000000) {
      return '$symbol${(amount.abs() / 1000000).toStringAsFixed(1)}M';
    }
    if (amount.abs() >= 1000) {
      return '$symbol${(amount.abs() / 1000).toStringAsFixed(1)}K';
    }
    return currency(amount, symbol: symbol);
  }

  static String percentage(double pct, {int decimals = 0}) =>
      '${pct.toStringAsFixed(decimals)}%';

  // ── Dates ─────────────────────────────────────────────────────────────────

  static String date(DateTime dt) => _date.format(dt);
  static String dateShort(DateTime dt) => _dateShort.format(dt);
  static String monthYear(DateTime dt) => _monthYear.format(dt);
  static String monthShort(DateTime dt) => _monthShort.format(dt);
  static String dayOfWeek(DateTime dt) => _dayOfWeek.format(dt);
  static String time(DateTime dt) => _time.format(dt);

  static String relativeDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${diff}d ago';
    return dateShort(dt);
  }

  static String dueDateLabel(int dueDay) {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, dueDay);
    final diff = thisMonth.difference(now).inDays;
    if (diff < 0) return 'Overdue';
    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    if (diff <= 7) return 'Due in ${diff}d';
    return 'Due ${dateShort(thisMonth)}';
  }

  // ── Goals ─────────────────────────────────────────────────────────────────

  static String goalProgress(double current, double target) =>
      '${currency(current)} of ${currency(target)}';

  static String monthsToGoal(double remaining, double monthlyContribution) {
    if (monthlyContribution <= 0) return '—';
    final months = (remaining / monthlyContribution).ceil();
    if (months <= 0) return 'This month!';
    if (months < 12) return '$months months';
    final years = months ~/ 12;
    final rem = months % 12;
    return rem > 0 ? '$years yr $rem mo' : '$years years';
  }

  // ── Debt ─────────────────────────────────────────────────────────────────

  static String interestRate(double apr) => '${apr.toStringAsFixed(1)}% APR';

  static String debtFreedom(DateTime dt) {
    final months = dt.difference(DateTime.now()).inDays ~/ 30;
    if (months <= 0) return 'This month!';
    if (months < 12) return 'In $months months';
    final years = months ~/ 12;
    final rem = months % 12;
    return rem > 0 ? 'In $years yr ${rem}mo' : 'In $years years';
  }
}
