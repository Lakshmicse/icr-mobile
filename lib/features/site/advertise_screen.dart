import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import 'site_kit.dart';

/// A paid placement the app can describe: what it is, and what a month costs the person asking (their listing's quote;
/// null when they have nothing to promote).
class PlacementOffer {
  const PlacementOffer({required this.sku, required this.title, required this.body, this.monthlyPaisa});

  final String sku;
  final String title;
  final String body;
  final int? monthlyPaisa;
}

/// A placement the person has bought or been given (`GET /promotions/mine`).
class MyPlacement {
  const MyPlacement({required this.label, required this.status, this.startsAt, this.endsAt});

  final String label;
  final String status;
  final DateTime? startsAt;
  final DateTime? endsAt;

  factory MyPlacement.fromJson(Map<String, dynamic> json) => MyPlacement(
    label: json['label'] as String? ?? json['targetName'] as String? ?? json['sku'] as String? ?? 'Placement',
    status: json['status'] as String? ?? '',
    startsAt: DateTime.tryParse(json['startsAt'] as String? ?? ''),
    endsAt: DateTime.tryParse(json['endsAt'] as String? ?? ''),
  );
}

class AdvertiseData {
  const AdvertiseData({required this.offers, required this.mine});

  final List<PlacementOffer> offers;
  final List<MyPlacement> mine;
}

abstract class AdvertiseRepository {
  Future<AdvertiseData> read();
}

/// The two placements on sale (`PromotionSku`): their words are the website's (`billing.AdvertiseInner.offers`), their
/// price the person's own quote for a month.
class ApiAdvertiseRepository implements AdvertiseRepository {
  ApiAdvertiseRepository(this._api);

  final ApiClient _api;

  static const _offers = [
    (
      'DIRECTORY',
      'Featured in Supplier Mart',
      'Your listing ahead of other suppliers in Supplier Mart while the placement runs.',
    ),
    ('HERO', 'Homepage hero', 'Your listing card or a banner in the homepage hero. ICR reviews it before it runs.'),
  ];

  Future<int?> _quote(String sku) async {
    try {
      final res = await _api.dio.get<dynamic>('/promotions/quote', queryParameters: {'sku': sku, 'months': 1});
      return ((res.data as Map)['listPaisa'] as num?)?.toInt();
    } catch (_) {
      // Nothing to promote (or not allowed to): the placement is still described.
      return null;
    }
  }

  @override
  Future<AdvertiseData> read() async {
    try {
      final quotes = await Future.wait([for (final o in _offers) _quote(o.$1)]);
      final mine = await _api.dio.get<dynamic>('/promotions/mine');
      final rows = (mine.data as Map?)?['data'] as List? ?? const [];
      return AdvertiseData(
        offers: [
          for (final (i, o) in _offers.indexed)
            PlacementOffer(sku: o.$1, title: o.$2, body: o.$3, monthlyPaisa: quotes[i]),
        ],
        mine: [for (final r in rows) MyPlacement.fromJson((r as Map).cast<String, dynamic>())],
      );
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

String _rupees(int paisa) {
  final r = paisa / 100;
  final whole = r.truncate().toString();
  final grouped = whole.length > 3
      ? '${whole.substring(0, whole.length - 3).replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (m) => ',')},${whole.substring(whole.length - 3)}'
      : whole;
  return '₹$grouped';
}

/// Advertise on ICR (`/advertise`): the placements, what a month costs the person, and the ones they already have.
/// Starting one is a payment, so "Talk to us" opens the app's contact form with the placement named.
class AdvertiseScreen extends StatefulWidget {
  const AdvertiseScreen({super.key, this.repository, this.onBack, this.onTalk});

  final AdvertiseRepository? repository;
  final VoidCallback? onBack;

  /// "Talk to us" for a placement: the app's contact form with this subject.
  final void Function(String subject)? onTalk;

  @override
  State<AdvertiseScreen> createState() => _AdvertiseScreenState();
}

class _AdvertiseScreenState extends State<AdvertiseScreen> {
  late final AdvertiseRepository _repo = widget.repository ?? ApiAdvertiseRepository(context.read<ApiClient>());
  late Future<AdvertiseData> _data = _repo.read();

  @override
  Widget build(BuildContext context) {
    return SitePage(
      title: 'Advertise',
      onBack: widget.onBack,
      canvas: true,
      child: FutureBuilder<AdvertiseData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return SiteError(
              message: snapshot.error is ApiError
                  ? (snapshot.error! as ApiError).message
                  : "Couldn't read your placements.",
              onRetry: () => setState(() {
                _data = _repo.read();
              }),
            );
          }
          final data = snapshot.data;
          if (data == null) return const SiteLoading();
          return ListView(
            key: const Key('advertise.body'),
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              for (final o in data.offers) ...[
                SiteCard(
                  child: Column(
                    key: ValueKey('offer:${o.sku}'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.title, style: SiteText.heading),
                      const SizedBox(height: 4),
                      Text(o.body, style: SiteText.secondary),
                      if (o.monthlyPaisa != null) ...[
                        const SizedBox(height: 10),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: _rupees(o.monthlyPaisa!), style: SiteText.title),
                              TextSpan(text: '  a month + GST', style: SiteText.meta),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SiteButton(
                        key: ValueKey('talk:${o.sku}'),
                        label: 'Talk to us',
                        outlined: true,
                        onPressed: () => widget.onTalk?.call('Advertise: ${o.title}'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your placements', style: SiteText.subheading),
                    const SizedBox(height: 8),
                    if (data.mine.isEmpty)
                      Text('You have no placements yet.', style: SiteText.secondary)
                    else
                      for (final p in data.mine)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.campaign_outlined, size: 24, color: AppColors.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.label, style: SiteText.strong),
                                    Text(
                                      [
                                        p.status,
                                        if (p.endsAt != null)
                                          'until ${p.endsAt!.day}/${p.endsAt!.month}/${p.endsAt!.year}',
                                      ].where((s) => s.isNotEmpty).join(' • '),
                                      style: SiteText.meta,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
