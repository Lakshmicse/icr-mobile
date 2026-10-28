import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import '../../core/util/time_ago.dart';
import '../../core/widgets/buttons.dart';
import '../jobs/job_detail_sheet.dart';
import '../jobs/job_links.dart';
import '../jobs/jobs_navigation.dart';
import 'career_base.dart';
import 'career_models.dart';
import 'career_repository.dart';
import 'career_styles.dart';
import 'career_widgets.dart';

/// "Invitations": the roles recruiters invited the member to apply for, and the switch
/// that lets recruiters find their résumé at all.
class InvitationsController extends CareerController {
  InvitationsController(super.repository, {super.clock});

  List<JobInvite> _invites = const [];
  bool? _discoverable;
  bool _discoverableLoaded = false;
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  List<JobInvite> get invites => _invites;
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  /// Whether recruiters can find the résumé; null when there is no résumé.
  bool? get discoverable => _discoverable;
  bool get discoverableLoaded => _discoverableLoaded;

  Future<void> start() async {
    await Future.wait([_load(), _loadDiscoverable(), loadUnread()]);
  }

  Future<void> refresh() => start();

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _invites = await repository.invites();
      _loaded = true;
    } catch (e) {
      _error = ApiError.from(e).message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadDiscoverable() async {
    try {
      _discoverable = await repository.discoverable();
    } catch (_) {
      _discoverable = null;
    }
    _discoverableLoaded = true;
    notifyListeners();
  }

  /// The switch: applied at once, put back with the API's sentence if refused.
  Future<String?> setDiscoverable(bool on) async {
    final before = _discoverable;
    _discoverable = on;
    notifyListeners();
    try {
      await repository.setDiscoverable(on);
      return null;
    } catch (e) {
      _discoverable = before;
      notifyListeners();
      return ApiError.from(e).message;
    }
  }

  /// Opening an invitation tells the recruiter it was seen (SENT becomes VIEWED).
  Future<void> markViewed(JobInvite invite) async {
    if (invite.status != 'SENT') return;
    try {
      await repository.respondToInvite(invite.id, decline: false);
      _invites = [for (final i in _invites) i.id == invite.id ? i.copyWith(status: 'VIEWED') : i];
      notifyListeners();
    } catch (_) {
      // Still opens; the recruiter just is not told yet.
    }
  }

  /// "Decline": the invitation leaves the list at once; a sentence when the API refuses.
  Future<String?> decline(JobInvite invite) async {
    final before = _invites;
    _invites = _invites.where((i) => i.id != invite.id).toList();
    notifyListeners();
    try {
      await repository.respondToInvite(invite.id, decline: true);
      return null;
    } catch (e) {
      _invites = before;
      notifyListeners();
      return ApiError.from(e).message;
    }
  }
}

class InvitationsScreen extends StatefulWidget {
  const InvitationsScreen({
    super.key,
    required this.repository,
    this.links = const SystemJobLinks(),
    this.navigation = JobsNavigation.none,
    this.onBack,
  });

  final CareerRepository repository;
  final JobLinks links;
  final JobsNavigation navigation;
  final VoidCallback? onBack;

  @override
  State<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends State<InvitationsScreen> {
  late final InvitationsController _c = InvitationsController(widget.repository);

  @override
  void initState() {
    super.initState();
    _c.start();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _open(JobInvite invite) async {
    _c.markViewed(invite);
    await showJobDetail(
      context,
      invite.job,
      repository: widget.repository.jobs,
      links: widget.links,
      navigation: widget.navigation,
      // Applying through an invitation closes it: read the list again.
      onApplied: (_) => _c.refresh(),
    );
  }

  Future<void> _decline(JobInvite invite) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        key: const ValueKey('decline-invite-dialog'),
        title: const Text('Decline this invitation?'),
        content: Text(
          '${invite.invitedBy ?? 'The recruiter'} will be told you are not interested in ${invite.jobTitle}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          TextButton(
            key: const ValueKey('decline-invite-confirm'),
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final message = await _c.decline(invite);
    if (!mounted) return;
    showMessage(context, message ?? 'Invitation declined.');
  }

  Future<void> _visibility(bool on) async {
    final message = await _c.setDiscoverable(on);
    if (message != null && mounted) showMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => CareerScaffold(
        title: 'Invitations',
        onBack: widget.onBack,
        unread: _c.unread,
        onBell: () => widget.navigation.openNotifications(context, widget.links),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _c.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 32),
            children: [
              _Visibility(
                discoverable: _c.discoverable,
                loaded: _c.discoverableLoaded,
                onChanged: _visibility,
                onProfile: () => widget.navigation.editProfile(context, widget.links),
              ),
              const SizedBox(height: 14),
              ..._body(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body() {
    if (_c.error != null && !_c.loaded) {
      return [
        CareerNotice(
          key: const ValueKey('invites-error'),
          icon: LucideIcons.cloudOff,
          title: "Couldn't load your invitations",
          body: _c.error!,
          action: 'Try again',
          onAction: _c.refresh,
        ),
      ];
    }
    if (!_c.loaded) return const [CareerLoading()];
    if (_c.invites.isEmpty) {
      return const [
        CareerNotice(
          key: ValueKey('invites-empty'),
          icon: LucideIcons.mailOpen,
          title: 'No invitations yet',
          body: 'When a recruiter invites you to apply for a role, it shows up here.',
        ),
      ];
    }
    return [
      for (final invite in _c.invites) ...[
        _InviteCard(invite: invite, onOpen: () => _open(invite), onDecline: () => _decline(invite)),
        const SizedBox(height: 10),
      ],
    ];
  }
}

class _Visibility extends StatelessWidget {
  const _Visibility({
    required this.discoverable,
    required this.loaded,
    required this.onChanged,
    required this.onProfile,
  });

  final bool? discoverable;
  final bool loaded;
  final ValueChanged<bool> onChanged;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('visibility'),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Open to opportunities', style: CareerText.cardTitle.copyWith(fontSize: 14))),
              Switch(
                key: const ValueKey('discoverable-switch'),
                value: discoverable ?? false,
                onChanged: discoverable == null ? null : onChanged,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text('When on, recruiters can find your résumé and invite you to apply.', style: CareerText.body),
          ),
          if (loaded && discoverable == null)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: Row(
                key: const ValueKey('no-resume'),
                children: [
                  const Icon(LucideIcons.info, size: 15, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Add a résumé to your profile to appear in recruiters\' searches.',
                      style: CareerText.body,
                    ),
                  ),
                  TextButton(
                    onPressed: onProfile,
                    child: Text('Profile', style: CareerText.link),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.invite, required this.onOpen, required this.onDecline});

  final JobInvite invite;
  final VoidCallback onOpen;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final where = [?invite.companyName, ?invite.city].join(' • ');
    return TapCard(
      key: ValueKey('invite-${invite.id}'),
      onTap: onOpen,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(invite.jobTitle, style: CareerText.cardTitle.copyWith(fontSize: 14), maxLines: 2)),
              if (invite.status == 'VIEWED') const StatusPill('Viewed'),
            ],
          ),
          if (where.isNotEmpty) Text(where, style: CareerText.companyMeta),
          const SizedBox(height: 2),
          Text(
            '${invite.invitedBy == null ? 'A recruiter' : 'Invited by ${invite.invitedBy}'} • ${timeAgo(invite.createdAt)}',
            style: CareerText.meta,
          ),
          if (invite.message != null && invite.message!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('“${invite.message!.trim()}”', style: CareerText.body.copyWith(fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                key: ValueKey('decline-${invite.id}'),
                onPressed: onDecline,
                child: Text('Decline', style: CareerText.link.copyWith(color: AppColors.onSurfaceVariant)),
              ),
              const Spacer(),
              SizedBox(
                width: 130,
                child: PrimaryButton(
                  key: ValueKey('open-${invite.id}'),
                  label: 'View & apply',
                  height: 34,
                  radius: 17,
                  textStyle: CareerText.link.copyWith(color: Colors.white),
                  onPressed: onOpen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
