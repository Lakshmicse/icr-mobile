import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/title_bar.dart';

/// One benefit the member has, and where it comes from (`GET /subscriptions/entitlements/explain`).
class PlanBenefit {
  const PlanBenefit({
    required this.label,
    required this.text,
    required this.area,
    required this.from,
    this.flag = false,
  });

  final String label;

  /// The plan card's wording of the value ("10 a month", "Unlimited job applications").
  final String text;
  final String area;

  /// "From your Pro plan", "From the free plan", "Extra from ICR".
  final String from;

  /// A yes/no benefit, read as its label alone.
  final bool flag;

  /// What the row says: a flag's label, else the card's wording.
  String get line => flag ? label : text;

  static PlanBenefit? fromJson(Map<String, dynamic> j) {
    if (j['shown'] == false) return null;
    final source = (j['source'] as Map?)?.cast<String, dynamic>() ?? const {};
    final plan = (source['planName'] as String?) ?? '';
    final via = source['via'] as String?;
    final from = switch (source['type']) {
      'GRANT' => via == 'COMPANY' ? 'Extra from ICR, for your company' : 'Extra from ICR',
      'FREE_PLAN' => 'From the free plan${plan.isEmpty ? '' : ' ($plan)'}',
      _ =>
        via == 'COMPANY'
            ? 'From your company\'s $plan plan'
            : via == 'INSTITUTE'
            ? 'From your institute\'s $plan plan'
            : plan.isEmpty
            ? 'From your plan'
            : 'From your $plan plan',
    };
    final kind = j['kind'] as String?;
    return PlanBenefit(
      label: (j['label'] as String?) ?? '',
      text: (j['text'] as String?) ?? (j['label'] as String?) ?? '',
      area: (j['area'] as String?) ?? 'OTHER',
      from: from,
      flag: kind == 'FLAG' || kind == 'NOTE',
    );
  }
}

/// "What my plans include" (the website's `/membership/benefits`): every benefit the member has across their plans,
/// grouped as the plan cards group them, each saying which plan gives it.
class PlanBenefitsScreen extends StatefulWidget {
  const PlanBenefitsScreen({super.key, this.onBack, this.onBell, this.unread = 0, this.onSeePlans});

  final VoidCallback? onBack;
  final VoidCallback? onBell;
  final int unread;

  /// The plans, to add to what is here.
  final VoidCallback? onSeePlans;

  @override
  State<PlanBenefitsScreen> createState() => _PlanBenefitsScreenState();
}

class _PlanBenefitsScreenState extends State<PlanBenefitsScreen> {
  late Future<List<PlanBenefit>> _benefits = _load();

  Future<List<PlanBenefit>> _load() async {
    try {
      final res = await context.read<ApiClient>().dio.get<Map<String, dynamic>>('/subscriptions/entitlements/explain');
      final list = (res.data?['benefits'] as List? ?? const []).cast<Map<String, dynamic>>();
      return [for (final b in list) ?PlanBenefit.fromJson(b)];
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TitleBar(
              title: 'What My Plans Include',
              onBack: widget.onBack,
              unread: widget.unread,
              onBell: widget.onBell ?? () {},
            ),
            Expanded(
              child: FutureBuilder<List<PlanBenefit>>(
                future: _benefits,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return _Centered(
                      text: snap.error is ApiError ? (snap.error! as ApiError).message : 'Unable to load your plans.',
                      action: 'Try Again',
                      onAction: () => setState(() => _benefits = _load()),
                    );
                  }
                  final all = snap.data ?? const [];
                  if (all.isEmpty) {
                    return _Centered(
                      text: 'Your plans include nothing extra yet.',
                      action: widget.onSeePlans == null ? null : 'See Plans',
                      onAction: widget.onSeePlans,
                    );
                  }
                  final areas = <String, List<PlanBenefit>>{
                    for (final key in [..._areas.keys, 'OTHER'])
                      if (all.any((b) => (_areas.containsKey(b.area) ? b.area : 'OTHER') == key))
                        key: [
                          for (final b in all)
                            if ((_areas.containsKey(b.area) ? b.area : 'OTHER') == key) b,
                        ],
                  };
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      for (final entry in areas.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                          child: Text(
                            _areaTitle(entry.key).toUpperCase(),
                            style: AppText.plexSans(12, FontWeight.w600, AppColors.onSurfaceVariant),
                          ),
                        ),
                        for (var i = 0; i < entry.value.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, thickness: 1, indent: 48, color: AppColors.outlineVariant),
                          _BenefitRow(benefit: entry.value[i]),
                        ],
                      ],
                      if (widget.onSeePlans != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                          child: OutlinedButton(onPressed: widget.onSeePlans, child: const Text('See Plans')),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The website's headings for an area (`BENEFIT_AREAS`), in its order.
  static const _areas = {
    'RFQ': 'Winning Work',
    'LISTING': 'Your Listing',
    'TALENT': 'Hiring',
    'JOBS': 'Jobs',
    'TEAM': 'Your Team',
    'COURSES': 'Courses and Learners',
    'INSIGHTS': 'Insights',
    'PROMOTION': 'Visibility',
    'MENTORSHIP': 'Mentoring',
    'DISCOUNTS': 'Member Prices',
    'CONTENT': 'Learning: Access',
    'LEARNING_DISCOUNTS': 'Learning: Discounts',
    'SUPPORT': 'Support',
    'SERVICE': 'Service Terms',
  };

  static String _areaTitle(String area) => _areas[area] ?? 'Other';
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.benefit});

  final PlanBenefit benefit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.check_circle_outline, size: 20, color: AppColors.tertiary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(benefit.line, style: AppText.plexSans(14, FontWeight.w500, AppColors.onSurface)),
                const SizedBox(height: 2),
                Text(benefit.from, style: AppText.plexSans(12, FontWeight.w400, AppColors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppText.plexSans(14, FontWeight.w400, AppColors.onSurfaceVariant),
          ),
          if (action != null && onAction != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    ),
  );
}
