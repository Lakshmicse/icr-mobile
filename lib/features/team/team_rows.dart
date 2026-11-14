import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../account/widgets/account_kit.dart';
import 'team_models.dart';
import 'team_rules.dart';
import 'team_words.dart';

/// The Team page's tabs as pills with their counts: the one on show is filled blue, the others are a tint (no frame).
class TeamTabs extends StatelessWidget {
  const TeamTabs({super.key, required this.selected, required this.counts, required this.onSelect});

  final TeamTab selected;
  final Map<TeamTab, int> counts;
  final ValueChanged<TeamTab> onSelect;

  static const _labels = {
    TeamTab.members: TeamWords.members,
    TeamTab.requests: TeamWords.requests,
    TeamTab.pending: TeamWords.pending,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          for (final tab in TeamTab.values) ...[
            Expanded(
              child: _Pill(tab: tab, on: tab == selected, count: counts[tab] ?? 0, onTap: () => onSelect(tab)),
            ),
            if (tab != TeamTab.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.tab, required this.on, required this.count, required this.onTap});

  final TeamTab tab;
  final bool on;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // A request or a pending add is something an admin has to answer: its count is drawn amber when it is not the
    // tab on show, so it is not missed.
    final waiting = tab != TeamTab.members && count > 0 && !on;
    return Semantics(
      button: true,
      selected: on,
      child: Material(
        color: on ? AppColors.primary : (waiting ? AppColors.amber50 : AppColors.slate100),
        shape: const StadiumBorder(),
        child: InkWell(
          key: Key('team.tab.${tab.name}'),
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 36,
            child: Center(
              child: Text(
                '${TeamTabs._labels[tab]} $count',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AccountText.label.copyWith(
                  color: on ? Colors.white : (waiting ? AppColors.amber800 : AppColors.slate700),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A block of rows: a white card with a heading, the rows under it separated by hairlines.
class TeamSection extends StatelessWidget {
  const TeamSection({super.key, this.title, this.lead, required this.children});

  final String? title;
  final String? lead;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, lead == null ? 8 : 2),
                child: Text(title!, style: AccountText.cardTitle),
              ),
            if (lead != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(lead!, style: AccountText.meta),
              ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// The hairline above a row (none above the first).
BoxDecoration _rowRule(bool first) => BoxDecoration(
  border: Border(top: first ? BorderSide.none : const BorderSide(color: AppColors.slate200)),
);

const _rowPadding = EdgeInsets.fromLTRB(16, 12, 16, 12);

/// One member: who they are, their role and office, what they answer in the inbox, and, for the people who may,
/// Edit and Remove.
class MemberRow extends StatelessWidget {
  const MemberRow({
    super.key,
    required this.member,
    required this.first,
    required this.canEdit,
    required this.canRemove,
    required this.removing,
    required this.disabled,
    required this.onEdit,
    required this.onRemove,
    this.onOpen,
  });

  final TeamMember member;
  final bool first;
  final bool canEdit;
  final bool canRemove;
  final bool removing;

  /// Another change is running: nothing else may start.
  final bool disabled;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final m = member;
    return Container(
      key: Key('team.member.${m.id}'),
      decoration: _rowRule(first),
      padding: _rowPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('team.member.open.${m.id}'),
            onTap: onOpen,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AccountAvatar(url: null, initials: teamInitials(m.firstName, m.lastName), size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AccountText.itemTitle),
                      Text(m.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: AccountText.meta),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AccountChip(label: teamRoleLabel(m.role, m.learningRoles)),
              for (final r in m.learningRoles)
                AccountChip(label: learningRoleLabel(r), color: AppColors.chipEmphasis, ink: AppColors.primary),
              AccountChip(label: m.branchName ?? TeamWords.companyWide, icon: Symbols.apartment),
              m.isActive
                  ? const AccountChip(label: TeamWords.active, color: AppColors.emerald50, ink: AppColors.emerald700)
                  : const AccountChip(label: TeamWords.deactivated, color: AppColors.slate100, ink: AppColors.slate500),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Inbox Permissions: ${TeamWords.inbox(m.handlesTopics)}',
            key: Key('team.member.inbox.${m.id}'),
            style: AccountText.meta,
          ),
          if (canEdit || canRemove) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canEdit)
                  AccountButton(
                    key: Key('team.edit.${m.id}'),
                    label: TeamWords.edit,
                    icon: Symbols.edit,
                    outlined: true,
                    expand: false,
                    height: 36,
                    onPressed: disabled ? null : onEdit,
                  ),
                if (canRemove)
                  AccountButton(
                    key: Key('team.remove.${m.id}'),
                    label: removing ? 'Removing…' : TeamWords.remove,
                    icon: Symbols.person_remove,
                    busy: removing,
                    outlined: true,
                    danger: true,
                    expand: false,
                    height: 36,
                    onPressed: disabled ? null : onRemove,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Someone who asked to join: their note, and Approve (the admin names the role) or Decline.
class RequestRow extends StatelessWidget {
  const RequestRow({
    super.key,
    required this.request,
    required this.first,
    required this.approving,
    required this.declining,
    required this.disabled,
    required this.onApprove,
    required this.onDecline,
    this.onOpen,
    this.now,
  });

  final TeamRequest request;
  final bool first;
  final bool approving;
  final bool declining;
  final bool disabled;
  final VoidCallback onApprove;
  final VoidCallback onDecline;
  final VoidCallback? onOpen;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Container(
      key: Key('team.request.${r.userId}'),
      decoration: _rowRule(first),
      padding: _rowPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('team.request.open.${r.userId}'),
            onTap: onOpen,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                AccountAvatar(url: r.avatarUrl, initials: teamInitials(r.firstName, r.lastName), size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AccountText.itemTitle),
                      Text(
                        '${TeamWords.asked(r, now: now)} · as ${teamRoleLabel(r.role, const [])}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AccountText.meta,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (r.note != null) ...[
            const SizedBox(height: 8),
            Text('“${r.note}”', style: AccountText.body.copyWith(fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              AccountButton(
                key: Key('team.approve.${r.userId}'),
                label: TeamWords.approve,
                icon: Symbols.check,
                busy: approving,
                expand: false,
                height: 36,
                onPressed: disabled ? null : onApprove,
              ),
              const SizedBox(width: 8),
              AccountButton(
                key: Key('team.decline.${r.userId}'),
                label: declining ? 'Declining…' : TeamWords.decline,
                busy: declining,
                outlined: true,
                danger: true,
                expand: false,
                height: 36,
                onPressed: disabled ? null : onDecline,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Someone an admin added from ICR who has not answered; the add can be taken back meanwhile.
class PendingAddRow extends StatelessWidget {
  const PendingAddRow({
    super.key,
    required this.add,
    required this.first,
    required this.canCancel,
    required this.cancelling,
    required this.disabled,
    required this.onCancel,
    this.now,
  });

  final PendingAdd add;
  final bool first;
  final bool canCancel;
  final bool cancelling;
  final bool disabled;
  final VoidCallback onCancel;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final a = add;
    return Container(
      key: Key('team.add.${a.userId}'),
      decoration: _rowRule(first),
      padding: _rowPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AccountAvatar(url: a.avatarUrl, initials: teamInitials(a.firstName, a.lastName), size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AccountText.itemTitle),
                    Text(TeamWords.added(a, now: now), style: AccountText.meta),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AccountChip(label: teamRoleLabel(a.role, a.learningRoles)),
              for (final r in a.learningRoles)
                AccountChip(label: learningRoleLabel(r), color: AppColors.chipEmphasis, ink: AppColors.primary),
              if (a.branchName != null) AccountChip(label: a.branchName!, icon: Symbols.apartment),
              if (canCancel)
                AccountButton(
                  key: Key('team.cancelAdd.${a.userId}'),
                  label: cancelling ? 'Cancelling…' : TeamWords.cancel,
                  busy: cancelling,
                  outlined: true,
                  danger: true,
                  expand: false,
                  height: 34,
                  onPressed: disabled ? null : onCancel,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// An email invite nobody has accepted: the address, the role and office, when it lapses, and Revoke.
class InviteRow extends StatelessWidget {
  const InviteRow({
    super.key,
    required this.invite,
    required this.first,
    required this.canRevoke,
    required this.revoking,
    required this.disabled,
    required this.onRevoke,
  });

  final TeamInvite invite;
  final bool first;
  final bool canRevoke;
  final bool revoking;
  final bool disabled;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final i = invite;
    return Container(
      key: Key('team.invite.${i.id}'),
      decoration: _rowRule(first),
      padding: _rowPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: AppColors.slate100, shape: BoxShape.circle),
                child: const Icon(Symbols.mail, size: 20, color: AppColors.slate500),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: AccountText.itemTitle),
                    if (i.expiresAt != null) Text(TeamWords.expires(i.expiresAt!), style: AccountText.meta),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AccountChip(label: teamRoleLabel(i.role, i.learningRoles)),
              for (final r in i.learningRoles)
                AccountChip(label: learningRoleLabel(r), color: AppColors.chipEmphasis, ink: AppColors.primary),
              if (i.branchName != null) AccountChip(label: i.branchName!, icon: Symbols.apartment),
              if (canRevoke)
                AccountButton(
                  key: Key('team.revoke.${i.id}'),
                  label: revoking ? 'Revoking…' : TeamWords.revoke,
                  busy: revoking,
                  outlined: true,
                  danger: true,
                  expand: false,
                  height: 34,
                  onPressed: disabled ? null : onRevoke,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A short grey sentence in a card: nothing here yet.
class TeamEmpty extends StatelessWidget {
  const TeamEmpty({super.key, required this.text, this.title, this.icon = Symbols.groups});

  final String? title;
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, size: 24, color: AppColors.slate500),
          ),
          const SizedBox(height: 10),
          if (title != null) ...[
            Text(title!, style: AccountText.cardTitle, textAlign: TextAlign.center),
            const SizedBox(height: 4),
          ],
          Text(text, style: AccountText.body, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
