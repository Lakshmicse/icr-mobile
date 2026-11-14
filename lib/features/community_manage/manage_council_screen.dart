import 'package:flutter/material.dart';

import 'community_manage_kit.dart';
import 'community_manage_models.dart';
import 'community_manage_repository.dart';
import 'org_record_page.dart';

/// One council's manage page (the website's `/admin/community?tab=councils` row: its Edit dialog, its "Manage
/// content" drawer — Resources, Updates, Leadership — and Retire). For staff holding `councils:manage` over this
/// council; [everywhere] says the key is held over every council, which Retire needs.
class ManageCouncilScreen extends StatelessWidget {
  const ManageCouncilScreen({
    super.key,
    required this.repository,
    required this.councilId,
    required this.everywhere,
    required this.onBack,
    this.onBell,
    this.unread = 0,
    this.pageWrap,
    this.initial,
    this.pickers = const ManagePickers(),
    this.now = DateTime.now,
  });

  final CommunityManageRepository repository;
  final String councilId;
  final bool everywhere;
  final VoidCallback onBack;
  final VoidCallback? onBell;
  final int unread;

  /// Wraps a page this one would push. It pushes none (its forms are sheets), so this is only carried.
  final Widget Function(Widget page)? pageWrap;

  /// The council as the list already read it, drawn at once while the page reads it again.
  final AdminCouncil? initial;
  final ManagePickers pickers;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) => OrgRecordPage(
    repository: repository,
    kind: OrgKind.council,
    id: councilId,
    everywhere: everywhere,
    onBack: onBack,
    onBell: onBell,
    unread: unread,
    initialCouncil: initial,
    pickers: pickers,
    now: now,
  );
}
