import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import 'api_notifications_repository.dart';
import 'notifications_repository.dart';
import 'unread_counts.dart';

/// A record's page calls this once it is open: whatever told the person about
/// it (a bid, an application, a thread) is read, however they got there, and
/// the bell follows. [kind] and [id] are the API's target kind and record id
/// (`NotificationTarget.kind` and `.recordId`: `'rfq.supplier'`, the rfq id).
///
///     initState: unawaited(markNotificationsSeen(context, NotificationKinds.rfqSupplier, rfqId));
///
/// A failure is ignored: the bell catches up on its next read.
Future<void> markNotificationsSeen(BuildContext context, String kind, String id) async {
  final counts = Provider.of<UnreadCounts?>(context, listen: false);
  final repository =
      Provider.of<NotificationsRepository?>(context, listen: false) ??
      ApiNotificationsRepository(api: context.read<ApiClient>());
  try {
    final read = await repository.markSeen(kind, id);
    if (read > 0 && counts != null) unawaited(counts.refresh());
  } catch (_) {}
}
