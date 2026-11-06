/// Web addresses typed into a post, a comment or a reply, made tappable (owner, 5 Nov 2026: "Links in the posts
/// should redirect to the link and be clickable"). An ICR address opens the app's own screen for it through
/// `openUrl` (the site route table), any other the phone's browser.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'links.dart' show openUrl;

/// `https://…`, `http://…` or `www.…`, up to the next space; trailing punctuation is left as text.
final webAddress = RegExp(r'''(?:https?://|www\.)[^\s<>"']+''', caseSensitive: false);

/// [text] cut into plain runs and web addresses, in order. An address has its trailing `.`, `,`, `)`… dropped
/// back into the text after it, and a `www.` address gains `https://`.
List<({String text, Uri? link})> splitLinks(String text) {
  final out = <({String text, Uri? link})>[];
  var at = 0;
  for (final m in webAddress.allMatches(text)) {
    var raw = m.group(0)!;
    final trimmed = raw.replaceFirst(RegExp(r'[.,;:!?)\]}]+$'), '');
    final tail = raw.substring(trimmed.length);
    raw = trimmed;
    final uri = Uri.tryParse(raw.toLowerCase().startsWith('www.') ? 'https://$raw' : raw);
    if (m.start > at) out.add((text: text.substring(at, m.start), link: null));
    if (uri == null || uri.host.isEmpty) {
      out.add((text: raw, link: null));
    } else {
      out.add((text: raw, link: uri));
    }
    if (tail.isNotEmpty) out.add((text: tail, link: null));
    at = m.end;
  }
  if (at < text.length) out.add((text: text.substring(at), link: null));
  return out;
}

/// Holds the tap recognisers of linked text, which must be disposed with the widget that drew them.
class LinkSpans {
  final _taps = <TapGestureRecognizer>[];

  /// The colour an address is drawn in.
  static const linkColor = AppColors.primary;

  /// [text] as spans: each web address a tappable span opening it ([onOpen], else `openUrl` from [context]); each
  /// plain run through [plain] (for @mentions), else as it is.
  List<InlineSpan> build(
    BuildContext context,
    String text, {
    void Function(Uri link)? onOpen,
    List<InlineSpan> Function(String run)? plain,
    TextStyle? linkStyle,
  }) {
    final spans = <InlineSpan>[];
    for (final part in splitLinks(text)) {
      final link = part.link;
      if (link == null) {
        spans.addAll(plain?.call(part.text) ?? [TextSpan(text: part.text)]);
        continue;
      }
      final tap = TapGestureRecognizer()..onTap = () => onOpen != null ? onOpen(link) : openUrl(context, link);
      _taps.add(tap);
      spans.add(
        TextSpan(
          text: part.text,
          style: linkStyle ?? const TextStyle(color: linkColor),
          recognizer: tap,
        ),
      );
    }
    return spans;
  }

  /// Whether [text] holds an address at all (a body without one can stay a plain `Text`).
  static bool hasLink(String text) => webAddress.hasMatch(text);

  /// Drops the recognisers of the last build; call before building again.
  void clear() {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
  }

  void dispose() => clear();
}
