/// Paisa as "₹4,999" or "₹1,00,000", the Indian grouping the website prints; paise only when there are any.
String rupees(int paisa) {
  final whole = paisa.abs() ~/ 100;
  final frac = paisa.abs() % 100;
  final digits = whole.toString();
  String grouped;
  if (digits.length <= 3) {
    grouped = digits;
  } else {
    final last = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    grouped = '${parts.join(',')},$last';
  }
  final sign = paisa < 0 ? '-' : '';
  return frac == 0 ? '$sign₹$grouped' : '$sign₹$grouped.${frac.toString().padLeft(2, '0')}';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "12 Mar 2027".
String dayLabel(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// "Renewed", "Changed plan", "Cancelled", "Ended", or null while the term runs.
String? termEndLabel(String? end) => switch (end) {
  'RENEWED' => 'Renewed',
  'CHANGED_PLAN' => 'Changed plan',
  'CANCELLED' => 'Cancelled',
  'ENDED' => 'Ended',
  _ => null,
};
