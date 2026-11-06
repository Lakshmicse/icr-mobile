/// Web addresses the Chapters and Councils pages are given by the API (a sponsor's site, a resource's file):
/// whether one is a link at all, and whether it is a real site or a placeholder.
library;

/// [raw] as a web link: an absolute `http` or `https` address with a host; null for anything else (empty, a bare
/// word, a `javascript:` or `file:` address), which the page treats as no link.
Uri? webLink(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return uri;
}

/// The names RFC 2606 keeps for examples. The demo data (`seed-association.ts` gives every chapter and council
/// resource and sponsor an `example.com` address) points at them, and no real organisation does, so a page that
/// opened one would leave the member on a dead browser page.
bool isPlaceholderLink(Uri uri) {
  final host = uri.host.toLowerCase();
  const reserved = ['example.com', 'example.org', 'example.net'];
  return reserved.any((d) => host == d || host.endsWith('.$d')) ||
      host.endsWith('.example') ||
      host.endsWith('.invalid');
}
