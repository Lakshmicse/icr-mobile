/// Words and numbers for the exam screens.
library;

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthsLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// The countdown: "09:05", or "1:30:00" when an hour or more is left.
String clockLabel(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '${_two(m)}:${_two(s)}';
}

/// The countdown in words, for a screen reader: "12 minutes 4 seconds".
String clockSpoken(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final parts = <String>[
    if (h > 0) '$h ${h == 1 ? 'hour' : 'hours'}',
    if (m > 0 || h > 0) '$m ${m == 1 ? 'minute' : 'minutes'}',
    '$s ${s == 1 ? 'second' : 'seconds'}',
  ];
  return parts.join(' ');
}

/// "12m 04s", as the website writes how long a sitting took.
String takenLabel(Duration d) {
  final total = (d.inMilliseconds / 1000).round();
  return '${total ~/ 60}m ${_two(total % 60)}s';
}

/// "18 Oct 2026".
String dayLabel(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  return '${l.day} ${_months[l.month - 1]} ${l.year}';
}

/// "18 Oct 2026, 13:05".
String dateTimeLabel(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  return '${dayLabel(l)}, ${_two(l.hour)}:${_two(l.minute)}';
}

/// "5 August 2026": the long form a certificate prints for the day it was cleared.
String longDayLabel(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  return '${l.day} ${_monthsLong[l.month - 1]} ${l.year}';
}

/// "12-AUG-2026": the short stamp a certificate prints for the day it was issued.
String stampLabel(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  return '${_two(l.day)}-${_months[l.month - 1].toUpperCase()}-${l.year}';
}

/// Indian grouping, as the website: 1180000 gives "11,80,000".
String groupThousands(int n) {
  final s = n.abs().toString();
  if (s.length <= 3) return n < 0 ? '-$s' : s;
  final last = s.substring(s.length - 3);
  var head = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (head.length > 2) {
    parts.insert(0, head.substring(head.length - 2));
    head = head.substring(0, head.length - 2);
  }
  if (head.isNotEmpty) parts.insert(0, head);
  return '${n < 0 ? '-' : ''}${parts.join(',')},$last';
}

/// "₹499" or "₹374.25" from paise; paise show only when there are some.
String rupees(int paise) {
  final whole = paise ~/ 100;
  final rest = paise % 100;
  return rest == 0 ? '₹${groupThousands(whole)}' : '₹${groupThousands(whole)}.${_two(rest)}';
}

/// Basis points as a percentage: 2500 gives "25%", 1850 gives "18.5%".
String percentOfBps(int bps) => bps % 100 == 0 ? '${bps ~/ 100}%' : '${(bps / 100).toStringAsFixed(1)}%';

/// "1 question" / "12 questions".
String plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';

/// The letter an option wears: A first. Past Z the number.
String optionLetter(int i) {
  const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  return i >= 0 && i < letters.length ? letters[i] : '${i + 1}';
}

/// "A, C": the letters of the options picked.
String optionLetters(Iterable<int> picks) => (picks.toList()..sort()).map(optionLetter).join(', ');
