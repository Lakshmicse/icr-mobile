import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/util/links.dart' show openSitePage;
import '../../core/widgets/title_bar.dart';

/// The website's words for a credit kind (`billing.CreditsRedemptionsPage.kinds`).
const _kinds = {
  'ASSESSMENT_UNLOCK': 'Assess your knowledge unlocks',
  'MOCK_UNLOCK': 'Mock exam unlocks',
  'DIRECTORY_PLACEMENT': 'Premium ads',
  'HERO_PLACEMENT': 'Banner highlights',
  'ICR_CREDIT': 'ICR credits',
};

/// …and for a redemption's state (`statuses`).
const _statuses = {
  'OPENED': 'Redeemed',
  'PENDING_PAYMENT': 'Pending',
  'PENDING': 'In review',
  'ACTIVE': 'Live',
  'EXPIRED': 'Ended',
  'REJECTED': 'Declined · credit returned',
  'REFUNDED': 'Refunded · credit returned',
  'ABANDONED': 'Not completed · credit returned',
};

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "4 Nov 2026".
String _day(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  return d == null ? '' : '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// "Credits & redemptions" (the website's `/refer/credits`): what the member holds of each credit, what they
/// redeemed, what they earned and how, and who joined through their invites (`GET /referrals/me/credits`).
class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key, this.onBack, this.onBell, this.unread = 0, this.onRefer});

  final VoidCallback? onBack;
  final VoidCallback? onBell;
  final int unread;

  /// "Refer a friend".
  final VoidCallback? onRefer;

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  late Future<Map<String, dynamic>> _history = _load();

  /// The open tab, as the website's page has them (owner, 5 Nov 2026: "like the tabs, not the vertical scrolling"):
  /// 0 Redemptions, 1 Credits earned, 2 Referred and Joined.
  int _tab = 0;

  Future<Map<String, dynamic>> _load() async {
    try {
      final res = await context.read<ApiClient>().dio.get<Map<String, dynamic>>('/referrals/me/credits');
      return res.data ?? const {};
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
              title: 'Credits & redemptions',
              onBack: widget.onBack,
              unread: widget.unread,
              onBell: widget.onBell ?? () {},
            ),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _history,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: TextButton(
                        onPressed: () => setState(() => _history = _load()),
                        child: const Text('We couldn’t load your credits. Please try again.'),
                      ),
                    );
                  }
                  return _body(snap.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(Map<String, dynamic> h) {
    List<Map<String, dynamic>> list(String key) => (h[key] as List? ?? const []).cast<Map<String, dynamic>>();
    final balances = list('balances').where((b) => ((b['granted'] as num?) ?? 0) > 0).toList();
    final redeemed = list('redeemed');
    final earned = list('earned');
    final invites = list('invites');
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'Every credit you’ve earned, how you earned it, and what you redeemed it on.',
            style: AppText.plexSans(13, FontWeight.w400, AppColors.onSurfaceVariant),
          ),
        ),
        if (balances.isEmpty)
          _Note(
            title: 'No credits yet',
            body:
                'Invite colleagues to ICR: every person who joins through your invite earns you ICR credits, more as '
                'more of them join, and suppliers earn free placements. Redeem ICR credits on assessment levels and '
                'mock exam sets.',
            action: widget.onRefer == null ? null : 'Refer a friend',
            onAction: widget.onRefer,
          )
        else
          for (final b in balances) _Balance(b: b),
        const SizedBox(height: 12),
        _Tabs(
          labels: [
            'Redemptions (${redeemed.length})',
            'Credits earned (${earned.length})',
            'Referred and Joined (${invites.length})',
          ],
          selected: _tab,
          onSelect: (i) => setState(() => _tab = i),
        ),
        ...switch (_tab) {
          0 =>
            redeemed.isEmpty
                ? [
                    const _Empty(
                      'You haven’t redeemed a credit yet. Use one on a locked assessment or mock exam, or on a '
                      'placement from Advertise.',
                    ),
                  ]
                : [
                    for (var i = 0; i < redeemed.length; i++) ...[
                      if (i > 0) const _Rule(),
                      _Row(
                        key: ValueKey('redeemed-$i'),
                        caption: _redeemedCaption(redeemed[i]),
                        title: _redeemedOn(redeemed[i]),
                        detail: _redeemedLine(redeemed[i]),
                        onTap: _paperPath(redeemed[i]) == null
                            ? null
                            : () => openSitePage(context, _paperPath(redeemed[i])!),
                      ),
                    ],
                  ],
          1 =>
            earned.isEmpty
                ? [const _Empty('No credits earned yet.')]
                : [
                    for (var i = 0; i < earned.length; i++) ...[
                      if (i > 0) const _Rule(),
                      _Row(title: _how(earned[i]), detail: _earnedLine(earned[i])),
                    ],
                  ],
          _ =>
            invites.isEmpty
                ? [const _Empty('Nobody has joined through your invite yet. Share your link from Refer a friend.')]
                : [
                    for (var i = 0; i < invites.length; i++) ...[
                      if (i > 0) const _Rule(),
                      _Row(title: (invites[i]['name'] as String?) ?? 'A member', detail: _inviteLine(invites[i])),
                    ],
                  ],
        },
      ],
    );
  }

  /// Above a redemption's title, as the website writes it: what the credit opened, or the placement it bought.
  static String _redeemedCaption(Map<String, dynamic> r) {
    final paper = (r['paper'] as Map?)?.cast<String, dynamic>();
    if (paper != null) return paper['kind'] == 'MOCK' ? 'Opened the mock exam' : 'Opened the assessment';
    final placement = (r['placement'] as Map?)?.cast<String, dynamic>();
    return placement?['sku'] == 'HERO' ? 'Homepage banner for a month' : 'Featured in Supplier Mart for a month';
  }

  /// Where a redeemed paper lives (the website's `paperHref`), which the app opens as its own screen.
  static String? _paperPath(Map<String, dynamic> r) {
    final p = (r['paper'] as Map?)?.cast<String, dynamic>();
    if (p == null) return null;
    if (p['kind'] == 'MOCK') {
      final topic = p['topicSlug'] as String?;
      return topic == null ? null : '/learning/mock-tests/$topic/${p['slug']}';
    }
    final code = p['courseCode'] as String?;
    return code == null ? null : '/learning/assessment/${code.toLowerCase()}/${p['slug']}';
  }

  /// What a credit was redeemed on: a paper ("Capital Planning – Foundation"), else a placement.
  static String _redeemedOn(Map<String, dynamic> r) {
    final paper = (r['paper'] as Map?)?.cast<String, dynamic>();
    if (paper != null) {
      final parent = paper['parentTitle'] as String?;
      return parent == null ? (paper['title'] as String? ?? '') : '$parent – ${paper['title']}';
    }
    final placement = (r['placement'] as Map?)?.cast<String, dynamic>();
    return (placement?['title'] as String?) ?? 'Your listing';
  }

  static String _redeemedLine(Map<String, dynamic> r) {
    final kind = _kinds[r['kind']] ?? '${r['kind']}';
    final placement = (r['placement'] as Map?)?.cast<String, dynamic>();
    final status = placement != null ? (_statuses[placement['status']] ?? '${placement['status']}') : 'Redeemed';
    return [_day(r['at'] as String?), '${r['quantity']} $kind', status].where((s) => s.isNotEmpty).join(' · ');
  }

  /// How a credit was earned, in the website's words.
  static String _how(Map<String, dynamic> e) {
    switch (e['source']) {
      case 'MILESTONE':
        final n = (e['invites'] as num?)?.toInt();
        if (n == null) return 'People joined through your invites';
        return n == 1 ? '1 person joined through your invites' : '$n people joined through your invites';
      case 'SIGNUP_GIFT':
        return 'Free when you joined ICR';
      case 'ADMIN':
        final reason = e['reason'] as String?;
        return reason == null || reason.isEmpty ? 'Added by ICR' : 'Added by ICR: $reason';
      default:
        final name = e['referee'] as String?;
        return name == null ? 'Someone joined through your invite' : '$name joined through your invite';
    }
  }

  static String _earnedLine(Map<String, dynamic> e) {
    final kind = _kinds[e['kind']] ?? '${e['kind']}';
    final expires = e['expiresAt'] as String?;
    final expiry = expires == null
        ? 'Never expires'
        : e['expired'] == true
        ? 'Expired after ${_day(expires)}'
        : 'Expires after ${_day(expires)}';
    return ['+${e['quantity']} $kind', _day(e['at'] as String?), expiry].where((s) => s.isNotEmpty).join(' · ');
  }

  static String _inviteLine(Map<String, dynamic> p) {
    final counted = p['counted'] == true
        ? 'Counts'
        : p['lapsed'] == true
        ? 'Not counted · credits lapsed'
        : 'Not counted';
    final credits = (p['credits'] as num?)?.toInt() ?? 0;
    return ['Joined ${_day(p['joinedAt'] as String?)}', counted, if (credits > 0) '+$credits ICR credits'].join(' · ');
  }
}

class _Balance extends StatelessWidget {
  const _Balance({required this.b});

  final Map<String, dynamic> b;

  @override
  Widget build(BuildContext context) {
    int n(String k) => (b[k] as num?)?.toInt() ?? 0;
    final next = (b['nextExpiry'] as Map?)?.cast<String, dynamic>();
    final detail = [
      '${n('granted')} earned',
      '${n('used')} redeemed',
      if (n('expired') > 0) '${n('expired')} expired',
      if (next != null) '${next['quantity']} expire after ${_day(next['expiresAt'] as String?)}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _kinds[b['kind']] ?? '${b['kind']}',
            style: AppText.plexSans(13, FontWeight.w600, AppColors.onSurfaceVariant),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${n('remaining')}', style: AppText.plexSans(22, FontWeight.w700, AppColors.onSurface)),
              const SizedBox(width: 6),
              Text('left', style: AppText.plexSans(13, FontWeight.w400, AppColors.onSurfaceVariant)),
            ],
          ),
          Text(detail, style: AppText.plexSans(12, FontWeight.w400, AppColors.onSurfaceVariant)),
          if (b['kind'] == 'ICR_CREDIT')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Redeem them on any Assess your knowledge level or mock exam set, from its page.',
                style: AppText.plexSans(12, FontWeight.w400, AppColors.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({super.key, required this.title, required this.detail, this.caption, this.onTap});

  final String title;
  final String detail;

  /// The small line above the title ("Opened the assessment").
  final String? caption;

  /// Opens what the row is about (a redeemed paper), drawn as a link like the website's.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (caption != null) ...[
            Text(caption!, style: AppText.plexSans(12, FontWeight.w400, AppColors.onSurfaceVariant)),
            const SizedBox(height: 2),
          ],
          Text(
            title,
            style: AppText.plexSans(
              14,
              onTap == null ? FontWeight.w500 : FontWeight.w600,
              onTap == null ? AppColors.onSurface : AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(detail, style: AppText.plexSans(12, FontWeight.w400, AppColors.onSurfaceVariant)),
        ],
      ),
    ),
  );
}

/// The three lists as tabs on one line, as the website's page has them: the open one in blue over a bar, a
/// hairline under them all; it scrolls sideways when the labels outgrow the phone.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.labels, required this.selected, required this.onSelect});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              for (final (i, label) in labels.indexed)
                Semantics(
                  selected: i == selected,
                  button: true,
                  child: InkWell(
                    key: ValueKey('credits-tab-$i'),
                    onTap: () => onSelect(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: IntrinsicWidth(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 10),
                            Text(
                              label,
                              textAlign: TextAlign.center,
                              style: AppText.plexSans(
                                14,
                                i == selected ? FontWeight.w600 : FontWeight.w500,
                                i == selected ? AppColors.primary : AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 9),
                            // The open tab's bar under its label: a line, not a frame.
                            Container(height: 2, color: i == selected ? AppColors.primary : Colors.transparent),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.outlineVariant),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, indent: 16, color: AppColors.outlineVariant);
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    child: Text(text, style: AppText.plexSans(13, FontWeight.w400, AppColors.onSurfaceVariant)),
  );
}

class _Note extends StatelessWidget {
  const _Note({required this.title, required this.body, this.action, this.onAction});

  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.plexSans(15, FontWeight.w600, AppColors.onSurface)),
        const SizedBox(height: 4),
        Text(body, style: AppText.plexSans(13, FontWeight.w400, AppColors.onSurfaceVariant)),
        if (action != null && onAction != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(onPressed: onAction, child: Text(action!)),
          ),
      ],
    ),
  );
}
