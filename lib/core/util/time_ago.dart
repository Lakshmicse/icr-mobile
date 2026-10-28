const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "just now", "42m ago", "5h ago", "3d ago", then the date ("12 Oct").
String timeAgo(DateTime at, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(at);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final local = at.toLocal();
  final sameYear = local.year == current.year;
  return '${local.day} ${_months[local.month - 1]}${sameYear ? '' : ' ${local.year}'}';
}

/// LinkedIn's short age, for a dense list: "now", "5m", "3h", "2d", "3w", "4mo", "2y".
String compactAge(DateTime at, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(at);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  if (diff.inDays < 30) return '${diff.inDays ~/ 7}w';
  if (diff.inDays < 365) return '${diff.inDays ~/ 30}mo';
  return '${diff.inDays ~/ 365}y';
}
