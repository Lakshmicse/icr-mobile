import 'package:flutter/material.dart';

import 'community_manage_kit.dart';
import 'community_manage_models.dart';
import 'community_manage_repository.dart';
import 'org_record_page.dart';

/// One chapter's manage page (the website's `/admin/community?tab=chapters` row: its Edit dialog, its "Manage
/// content" drawer — Sponsors, Resources, Updates, Leadership — and Retire). For staff holding `chapters:manage`
/// over this chapter; [everywhere] says the key is held over every chapter, which Retire and Add Leader need.
class ManageChapterScreen extends StatelessWidget {
  const ManageChapterScreen({
    super.key,
    required this.repository,
    required this.chapterId,
    required this.everywhere,
    required this.onBack,
    this.onBell,
    this.unread = 0,
    this.pageWrap,
    this.initial,
    this.pickers = const ManagePickers(),
    this.searchDelay = const Duration(milliseconds: 350),
    this.now = DateTime.now,
  });

  final CommunityManageRepository repository;
  final String chapterId;
  final bool everywhere;
  final VoidCallback onBack;
  final VoidCallback? onBell;
  final int unread;

  /// Wraps a page this one would push. It pushes none (its forms are sheets), so this is only carried.
  final Widget Function(Widget page)? pageWrap;

  /// The chapter as the list already read it, drawn at once while the page reads it again.
  final AdminChapter? initial;
  final ManagePickers pickers;
  final Duration searchDelay;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) => OrgRecordPage(
    repository: repository,
    kind: OrgKind.chapter,
    id: chapterId,
    everywhere: everywhere,
    onBack: onBack,
    onBell: onBell,
    unread: unread,
    initialChapter: initial,
    pickers: pickers,
    searchDelay: searchDelay,
    now: now,
  );
}
