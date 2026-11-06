import 'package:flutter/material.dart';

import '../../core/util/links.dart' show openSitePage;
import 'support_models.dart';
import 'support_repository.dart';
import 'support_screen.dart';
import 'ticket_screen.dart';

/// Opens "Help & support" (the website's `/support`) over whatever called it.
Future<void> openSupport(BuildContext context, {SupportRepository? repository, FilePickFn? pickFiles}) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (c) => SupportScreen(
          repository: repository,
          pickFiles: pickFiles,
          onBack: () => Navigator.of(c).pop(),
          onOpenContext: (href) => openSitePage(c, href),
        ),
      ),
    );

/// Opens one request (`/support/<id>`), as a notification or a link names it. [onOpened] runs once the request has
/// been read, with the screen's context: the caller reads what told the person about it (its notifications).
/// [onOpenContext] opens the page the request is about; the app's own screen for it (or its web view) when null.
Future<void> openSupportTicket(
  BuildContext context,
  String id, {
  SupportRepository? repository,
  FilePickFn? pickFiles,
  void Function(BuildContext context)? onOpened,
  void Function(String href)? onOpenContext,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (c) => TicketScreen(
      ticketId: id,
      repository: repository,
      pickFiles: pickFiles,
      onOpened: onOpened,
      onBack: () => Navigator.of(c).pop(),
      onOpenContext: onOpenContext ?? (href) => openSitePage(c, href),
    ),
  ),
);
