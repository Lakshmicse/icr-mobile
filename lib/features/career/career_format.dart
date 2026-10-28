/// Dates, times and money as the career and hiring screens write them.
library;

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "24 Oct 2026" (the year left out when it is this year's, unless [year]).
String formatDay(DateTime at, {DateTime? now, bool year = false}) {
  final d = at.toLocal();
  final thisYear = (now ?? DateTime.now()).year == d.year;
  return '${d.day} ${_months[d.month - 1]}${year || !thisYear ? ' ${d.year}' : ''}';
}

/// "Mon 27 Oct".
String formatWeekday(DateTime at) {
  final d = at.toLocal();
  return '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
}

/// "10:30 AM".
String formatTime(DateTime at) {
  final d = at.toLocal();
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// "Mon 27 Oct, 10:30 AM".
String formatWhen(DateTime at) => '${formatWeekday(at)}, ${formatTime(at)}';

/// The month's short name, upper case ("OCT"), for a date block.
String monthShort(DateTime at) => _months[at.toLocal().month - 1].toUpperCase();

/// Indian digit grouping: 1800000 → "18,00,000".
String groupIndian(num n) {
  final whole = n.round().abs().toString();
  if (whole.length <= 3) return '${n < 0 ? '-' : ''}$whole';
  final last = whole.substring(whole.length - 3);
  var rest = whole.substring(0, whole.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${n < 0 ? '-' : ''}${parts.join(',')},$last';
}

/// "₹18,00,000" (rupees), or the amount with its currency code ("USD 90,000").
String formatMoney(num amount, {String currency = 'INR'}) =>
    currency == 'INR' ? '₹${groupIndian(amount)}' : '$currency ${groupIndian(amount)}';

/// "₹18L" / "₹1.2Cr" / "₹45K": a short amount for a tight line.
String formatMoneyShort(num n) {
  String trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  final v = n.toDouble();
  if (v >= 1e7) return '₹${trim(v / 1e7)}Cr';
  if (v >= 1e5) return '₹${trim(v / 1e5)}L';
  if (v >= 1e3) return '₹${trim(v / 1e3)}K';
  return '₹${v.round()}';
}

/// "/ yr", "/ mo", "/ hr".
String periodSuffix(String period) => switch (period) {
  'MONTHLY' => '/ mo',
  'HOURLY' => '/ hr',
  _ => '/ yr',
};

/// "3 days ago", "today", "in 2 days".
String relativeDays(int days) => switch (days) {
  0 => 'today',
  1 => 'tomorrow',
  -1 => 'yesterday',
  > 1 => 'in $days days',
  _ => '${-days} days ago',
};
