import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/util/links.dart' show SiteRoutes;
import 'marketplace_models.dart';

/// Where a tap on the Marketplace leaves the app: the phone's dialler, WhatsApp,
/// a supplier's own site, the system share sheet. The screens go through it, so
/// a test can see where a control would have taken the member.
abstract class MarketplaceLinks {
  const MarketplaceLinks();

  /// Opens [uri] outside the app; false when nothing could open it.
  Future<bool> open(Uri uri);

  /// Hands [text] to the system share sheet.
  Future<void> share({required String text, String? subject});
}

/// The real thing: the dialler, the browser and the share sheet.
class SystemMarketplaceLinks extends MarketplaceLinks {
  const SystemMarketplaceLinks();

  @override
  Future<bool> open(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  Future<void> share({required String text, String? subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }
}

/// The digits of a phone number, with India's 91 put in front of a bare
/// ten-digit mobile (what `wa.me` wants).
String? whatsAppNumber(String? phone) {
  if (phone == null) return null;
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  if (digits.length == 10) return '91$digits';
  if (digits.length == 11 && digits.startsWith('0')) return '91${digits.substring(1)}';
  return digits;
}

/// A website the way a person typed it: with a scheme.
Uri? websiteUri(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return null;
  final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
  return uri == null || uri.host.isEmpty ? null : uri;
}

/// The supplier's page on the website, which is what a share carries.
Uri supplierPageUri(Supplier supplier) => AppConfig.sitePage('/companies/${Uri.encodeComponent(supplier.companyId)}');

extension MarketplaceLinksOpening on MarketplaceLinks {
  /// Opens [uri] — the app's own screen when it has one for that page of the
  /// website — and says so when the phone has nothing to open it with.
  Future<void> openUri(BuildContext context, Uri uri) async {
    final inApp = SiteRoutes.inApp(uri);
    if (inApp != null) return inApp(context);
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await open(uri);
    } catch (_) {
      // Treated as "could not open" below.
    }
    if (!opened) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("Couldn't open ${uri.host.isEmpty ? uri.scheme : uri.host}${uri.path}")));
    }
  }

  /// A page of the ICR website.
  Future<void> openSite(BuildContext context, String path) => openUri(context, AppConfig.sitePage(path));

  /// "Call HQ": the dialler with the head office's number.
  Future<void> call(BuildContext context, String phone) =>
      openUri(context, Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), '')));

  /// "WhatsApp": a chat with the number, opened with a first line.
  Future<void> chat(BuildContext context, String phone, {String? text}) {
    final number = whatsAppNumber(phone);
    if (number == null) return Future.value();
    return openUri(context, Uri.https('wa.me', '/$number', {'text': ?text}));
  }

  /// Shares the supplier's page on the website.
  Future<void> shareSupplier(Supplier supplier) =>
      share(text: '${supplier.name} on ICR Supplier Mart\n${supplierPageUri(supplier)}', subject: supplier.name);
}
