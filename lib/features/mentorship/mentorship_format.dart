/// How the Mentorship screens word a count they promise rather than state: the
/// design says "8+ Domains" and "Join 3,000+ senior leaders", so a live count is
/// rounded down to a figure that is always true, with a "+".
library;

/// [n] rounded down to the nearest 1, 5, 10, 50 or 500, whichever its size
/// calls for: 8 stays 8, 14 becomes 10, 58 becomes 50, 64 becomes 60, 123
/// becomes 100, 3,120 becomes 3,000. Never rounds up, so "N+" is never a lie.
int roundedDown(int n) {
  if (n <= 0) return 0;
  if (n < 10) return n;
  final step = n < 50
      ? 5
      : n < 100
      ? 10
      : n < 1000
      ? 50
      : 500;
  return n - n % step;
}

/// "8+", "50+", "3,000+": [roundedDown] with a thousands separator and a plus.
String plusCount(int n) => '${groupDigits(roundedDown(n))}+';

/// The pill beside "Explore by Companies": "8+ Domains". Empty when there are
/// none, so the pill is not drawn.
String domainsBadgeFor(int domains) => domains <= 0 ? '' : '${plusCount(domains)} Domains';

/// 1234567 as "1,234,567" (Western grouping, as the designs print numbers).
String groupDigits(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
