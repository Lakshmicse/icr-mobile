import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import 'site_kit.dart';

/// A member's invitations (`GET /referrals/me`): their code and link, what an invitee and the member each earn, and
/// where the invites stand.
class MyReferrals {
  const MyReferrals({
    required this.code,
    required this.link,
    required this.shareText,
    required this.programme,
    required this.refereeReward,
    required this.referrerReward,
    required this.invited,
    required this.verified,
    required this.rewarded,
    required this.capPerYear,
    required this.usedThisYear,
  });

  final String code;
  final String link;

  /// The invitation as it reads when shared (the API words it with the member's name).
  final String shareText;
  final String? programme;
  final String? refereeReward;
  final String? referrerReward;
  final int invited;
  final int verified;
  final int rewarded;
  final int? capPerYear;
  final int usedThisYear;

  factory MyReferrals.fromJson(Map<String, dynamic> json) {
    final programme = json['programme'] as Map<String, dynamic>?;
    final stats = json['stats'] as Map<String, dynamic>? ?? const {};
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    return MyReferrals(
      code: json['code'] as String? ?? '',
      link: json['link'] as String? ?? '',
      shareText: json['linkedinText'] as String? ?? json['emailText'] as String? ?? '',
      programme: programme?['name'] as String?,
      refereeReward: programme?['refereeReward'] as String?,
      referrerReward: programme?['referrerReward'] as String?,
      invited: n(stats['invited']),
      verified: n(stats['verified']),
      rewarded: n(stats['rewarded']),
      capPerYear: (stats['capPerYear'] as num?)?.toInt(),
      usedThisYear: n(stats['usedThisYear']),
    );
  }
}

abstract class ReferralsRepository {
  Future<MyReferrals> mine();
}

class ApiReferralsRepository implements ReferralsRepository {
  ApiReferralsRepository(this._api);

  final ApiClient _api;

  @override
  Future<MyReferrals> mine() async {
    try {
      final res = await _api.dio.get<dynamic>('/referrals/me');
      return MyReferrals.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

/// Invite people to ICR (`/refer`): the member's code and link to copy or share, the rewards, and how many have
/// joined.
class ReferScreen extends StatefulWidget {
  const ReferScreen({super.key, this.repository, this.onBack, this.share});

  final ReferralsRepository? repository;
  final VoidCallback? onBack;

  /// Hands the invitation to the share sheet; the system's by default.
  final Future<void> Function(String text)? share;

  @override
  State<ReferScreen> createState() => _ReferScreenState();
}

class _ReferScreenState extends State<ReferScreen> {
  late final ReferralsRepository _repo = widget.repository ?? ApiReferralsRepository(context.read<ApiClient>());
  late Future<MyReferrals> _mine = _repo.mine();

  Future<void> _share(MyReferrals r) async {
    final text = r.shareText.isEmpty ? r.link : r.shareText;
    if (widget.share != null) return widget.share!(text);
    await SharePlus.instance.share(ShareParams(text: text, subject: 'Join me on ICR'));
  }

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showMessage(context, '$what copied');
  }

  @override
  Widget build(BuildContext context) {
    return SitePage(
      title: 'Invite',
      onBack: widget.onBack,
      canvas: true,
      child: FutureBuilder<MyReferrals>(
        future: _mine,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return SiteError(
              message: snapshot.error is ApiError
                  ? (snapshot.error! as ApiError).message
                  : "Couldn't read your invitations.",
              onRetry: () => setState(() {
                _mine = _repo.mine();
              }),
            );
          }
          final r = snapshot.data;
          if (r == null) return const SiteLoading();
          return ListView(
            key: const Key('refer.body'),
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              SiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invite colleagues to ICR', style: SiteText.heading),
                    const SizedBox(height: 4),
                    Text(
                      r.programme == null
                          ? 'Share your link or code. Anyone who joins with it is connected to you.'
                          : '${r.programme}. Share your link or code.',
                      style: SiteText.secondary,
                    ),
                    const SizedBox(height: 16),
                    Text('Your code', style: SiteText.meta),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            r.code,
                            key: const Key('refer.code'),
                            style: SiteText.title.copyWith(letterSpacing: 1.5),
                          ),
                        ),
                        TextButton(
                          key: const Key('refer.copy.code'),
                          onPressed: () => _copy(r.code, 'Code'),
                          child: Text('Copy', style: SiteText.link),
                        ),
                      ],
                    ),
                    const Divider(color: SiteColors.hairline),
                    Text('Your link', style: SiteText.meta),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(r.link, style: SiteText.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                        TextButton(
                          key: const Key('refer.copy.link'),
                          onPressed: () => _copy(r.link, 'Link'),
                          child: Text('Copy', style: SiteText.link),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SiteButton(label: 'Share invitation', onPressed: () => _share(r)),
                  ],
                ),
              ),
              if (r.refereeReward != null || r.referrerReward != null) ...[
                const SizedBox(height: 8),
                SiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What you each get', style: SiteText.subheading),
                      const SizedBox(height: 8),
                      if (r.refereeReward != null) _line(Icons.card_giftcard_outlined, 'They get ${r.refereeReward}'),
                      if (r.referrerReward != null)
                        _line(Icons.workspace_premium_outlined, 'You get ${r.referrerReward}'),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              SiteCard(
                child: Row(
                  children: [_stat('Invited', r.invited), _stat('Joined', r.verified), _stat('Rewarded', r.rewarded)],
                ),
              ),
              if (r.capPerYear != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    '${r.usedThisYear} of ${r.capPerYear} rewarded invitations used this year',
                    style: SiteText.meta,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 24, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: SiteText.body)),
      ],
    ),
  );

  Widget _stat(String label, int n) => Expanded(
    child: Column(
      children: [
        Text('$n', style: SiteText.title),
        const SizedBox(height: 2),
        Text(label, style: SiteText.meta),
      ],
    ),
  );
}

Future<void> openRefer(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute(builder: (route) => ReferScreen(onBack: () => Navigator.of(route).pop())));
