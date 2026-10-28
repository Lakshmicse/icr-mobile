/// Reading what the API sends. The portal sends `null`, a number where the
/// field is a Decimal (as a string), and lists that are sometimes missing, so
/// every read goes through these and a wrong shape reads as "nothing".
library;

String? asText(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

int? asInt(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt();
  return null;
}

double? asDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

DateTime? asDate(Object? v) => v is String ? DateTime.tryParse(v) : null;

Map<String, dynamic> asMap(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};

List<Map<String, dynamic>> asMaps(Object? v) => [
  for (final e in v is List ? v : const [])
    if (e is Map) e.cast<String, dynamic>(),
];

List<String> asStrings(Object? v) => [
  for (final e in v is List ? v : const [])
    if (e is String && e.trim().isNotEmpty) e.trim(),
];

/// The rows of a `{ data, meta }` page, or of a bare list.
List<Map<String, dynamic>> rowsOf(Object? body) => body is Map ? asMaps(body['data']) : asMaps(body);

/// `meta.total` of a page, else [fallback].
int totalOf(Object? body, int fallback) => body is Map ? asInt(asMap(body['meta'])['total']) ?? fallback : fallback;

/// `meta.hasNext` of a page.
bool hasNextOf(Object? body) => body is Map && asMap(body['meta'])['hasNext'] == true;
