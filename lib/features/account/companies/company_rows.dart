import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../account_labels.dart';
import '../account_models.dart';
import '../widgets/account_kit.dart';
import 'company_words.dart';

/// A row of the "All workspaces" card: a hairline above it, and, for the
/// workspace being acted for, the wash and blue edge the website draws.
class WorkspaceRow extends StatelessWidget {
  const WorkspaceRow({super.key, required this.active, required this.child, this.first = false});

  final bool active;
  final bool first;
  final Widget child;

  static const _wash = Color(0xFFF3F8FD);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: active ? _wash : Colors.white,
        border: Border(
          top: first ? BorderSide.none : const BorderSide(color: AppColors.slate200),
          left: BorderSide(color: active ? AppColors.primary : Colors.transparent, width: 3),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(13, 14, 16, 14),
      child: child,
    );
  }
}

/// One company the person belongs to: its logo and name, the role and place,
/// the team, and what they can do with it (act for it, leave it).
class CompanyWorkspaceRow extends StatelessWidget {
  const CompanyWorkspaceRow({
    super.key,
    required this.company,
    required this.switchingHere,
    required this.disabled,
    required this.onSwitch,
    required this.onLeave,
    this.onOpen,
    this.first = false,
  });

  final MyCompany company;
  final bool switchingHere;

  /// Another action is running: nothing else may start.
  final bool disabled;
  final VoidCallback onSwitch;
  final VoidCallback onLeave;
  final VoidCallback? onOpen;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final c = company;
    final where = [?CompanyWords.place(c.city, c.state), ?c.branchName].join(' · ');
    return WorkspaceRow(
      key: Key('company.row.${c.companyId}'),
      active: c.active,
      first: first,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CompanyLogo(url: c.logoUrl, name: c.name, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AccountText.itemTitle,
                          ),
                        ),
                        if (c.verified) ...[
                          const SizedBox(width: 4),
                          Semantics(
                            label: 'Verified employer',
                            child: const Icon(Icons.verified_rounded, size: 16, color: AppColors.emerald700),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(roleLabel(c.role), key: Key('company.role.${c.companyId}'), style: AccountText.body),
                    if (where.isNotEmpty)
                      Text(where, maxLines: 2, overflow: TextOverflow.ellipsis, style: AccountText.meta),
                    if (c.industry != null)
                      Text(
                        industryLabel(c.industry) ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AccountText.meta,
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (c.active)
                          const AccountChip(
                            label: CompanyWords.active,
                            color: AppColors.chipEmphasis,
                            ink: AppColors.primary,
                            icon: Icons.check_rounded,
                          ),
                        if (c.hasSupplierListing) const AccountChip(label: 'Supplier'),
                        AccountChip(label: CompanyWords.members(c.memberCount)),
                        if ((c.pendingJoinRequests ?? 0) > 0)
                          AccountChip(
                            key: Key('company.waiting.${c.companyId}'),
                            label: CompanyWords.awaiting(c.pendingJoinRequests!),
                            color: AppColors.amber50,
                            ink: AppColors.amber800,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (c.soleAdmin)
            Row(
              key: Key('company.onlyAdmin.${c.companyId}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Symbols.shield_person, size: 16, color: AppColors.slate500),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(CompanyWords.onlyAdmin, style: AccountText.meta)),
              ],
            ),
          if (c.soleAdmin) const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!c.active)
                AccountButton(
                  key: Key('company.switch.${c.companyId}'),
                  label: switchingHere ? 'Switching…' : 'Switch to This Company',
                  busy: switchingHere,
                  outlined: true,
                  expand: false,
                  height: 40,
                  onPressed: disabled ? null : onSwitch,
                ),
              if (!c.soleAdmin)
                AccountButton(
                  key: Key('company.leave.${c.companyId}'),
                  label: 'Leave',
                  icon: Symbols.logout,
                  outlined: true,
                  danger: true,
                  expand: false,
                  height: 40,
                  onPressed: disabled ? null : onLeave,
                ),
              if (onOpen != null)
                TextButton(key: Key('company.open.${c.companyId}'), onPressed: onOpen, child: const Text('View Page')),
            ],
          ),
        ],
      ),
    );
  }
}

/// The person's own account: always there, always switchable.
class PersonalWorkspaceRow extends StatelessWidget {
  const PersonalWorkspaceRow({
    super.key,
    required this.personalRole,
    required this.active,
    required this.switchingHere,
    required this.disabled,
    required this.onSwitch,
    this.first = false,
  });

  final String personalRole;
  final bool active;
  final bool switchingHere;
  final bool disabled;
  final VoidCallback onSwitch;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return WorkspaceRow(
      key: const Key('company.personal'),
      active: active,
      first: first,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: AppColors.slate100, shape: BoxShape.circle),
                child: const Icon(Symbols.person, size: 22, color: AppColors.slate500),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(CompanyWords.personalAccount, style: AccountText.itemTitle),
                    const SizedBox(height: 2),
                    Text(roleLabel(personalRole), style: AccountText.body),
                    Text(CompanyWords.actingAsYourself, style: AccountText.meta),
                    if (active) ...[
                      const SizedBox(height: 8),
                      const AccountChip(
                        key: Key('company.personal.active'),
                        label: CompanyWords.active,
                        color: AppColors.chipEmphasis,
                        ink: AppColors.primary,
                        icon: Icons.check_rounded,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (!active) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: AccountButton(
                key: const Key('company.switch.personal'),
                label: switchingHere ? 'Switching…' : 'Switch to Personal Account',
                busy: switchingHere,
                outlined: true,
                expand: false,
                height: 40,
                onPressed: disabled ? null : onSwitch,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A request to join that no admin has decided: withdrawable while it waits.
class JoinRequestRow extends StatelessWidget {
  const JoinRequestRow({
    super.key,
    required this.request,
    required this.withdrawing,
    required this.disabled,
    required this.onWithdraw,
    this.first = false,
    this.now,
  });

  final JoinRequest request;
  final bool withdrawing;
  final bool disabled;
  final VoidCallback onWithdraw;
  final bool first;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Container(
      key: Key('request.row.${r.companyId}'),
      decoration: BoxDecoration(
        border: Border(top: first ? BorderSide.none : const BorderSide(color: AppColors.slate200)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CompanyLogo(url: r.logoUrl, name: r.name, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AccountText.itemTitle),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Symbols.hourglass_empty, size: 13, color: AppColors.slate500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        CompanyWords.requested(r, now: now),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AccountText.meta,
                      ),
                    ),
                  ],
                ),
                if (r.note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '“${r.note}”',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AccountText.meta.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AccountButton(
            key: Key('request.withdraw.${r.companyId}'),
            label: withdrawing ? 'Withdrawing…' : 'Withdraw',
            busy: withdrawing,
            outlined: true,
            expand: false,
            height: 36,
            onPressed: disabled ? null : onWithdraw,
          ),
        ],
      ),
    );
  }
}

/// A place an admin added the person to: they join only when they accept, and may decline. Both buttons wait while
/// either is being answered ([answering] names the one that is).
class InvitationRow extends StatelessWidget {
  const InvitationRow({
    super.key,
    required this.invitation,
    required this.answering,
    required this.disabled,
    required this.onAccept,
    required this.onDecline,
    this.first = false,
    this.now,
  });

  final CompanyInvitation invitation;

  /// `accept` or `decline` while this invitation is being answered, else null.
  final String? answering;
  final bool disabled;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool first;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final i = invitation;
    return Container(
      key: Key('invitation.row.${i.companyId}'),
      decoration: BoxDecoration(
        border: Border(top: first ? BorderSide.none : const BorderSide(color: AppColors.slate200)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CompanyLogo(url: i.logoUrl, name: i.name, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AccountText.itemTitle),
                    const SizedBox(height: 2),
                    Text(
                      CompanyWords.invited(i, now: now),
                      key: Key('invitation.added.${i.companyId}'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AccountText.meta,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AccountButton(
                  key: Key('invitation.decline.${i.companyId}'),
                  label: answering == 'decline' ? CompanyWords.declining : CompanyWords.decline,
                  busy: answering == 'decline',
                  outlined: true,
                  height: 38,
                  onPressed: disabled ? null : onDecline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AccountButton(
                  key: Key('invitation.accept.${i.companyId}'),
                  label: answering == 'accept' ? CompanyWords.accepting : CompanyWords.accept,
                  busy: answering == 'accept',
                  height: 38,
                  onPressed: disabled ? null : onAccept,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
