import 'package:flutter/material.dart';

import 'my_bids_screen.dart';
import 'my_rfqs_screen.dart';
import 'open_requirements_screen.dart';
import 'opportunity_screen.dart';
import 'post_rfq_screen.dart';
import 'rfq_alerts_screen.dart';
import 'rfq_detail_screen.dart';
import 'rfq_models.dart';
import 'rfq_scope.dart';

/// How one requirements screen opens another, carrying the same hooks.

/// The owner's page of a requirement, as a widget (for a route built elsewhere, a replacement after a post).
Widget rfqDetailFor(String rfqId, RfqHooks hooks, {String? section, String? focusBid}) => RfqDetailScreen(
  rfqId,
  section: section,
  focusBidId: focusBid,
  repository: hooks.repository,
  links: hooks.links,
  onOpenConversation: hooks.onOpenConversation,
  onOpenSupplier: hooks.onOpenSupplier,
  onCreateCompany: hooks.onCreateCompany,
);

/// The supplier's page of a requirement, as a widget.
Widget opportunityFor(String rfqId, RfqHooks hooks, {String? section}) => OpportunityScreen(
  rfqId,
  section: section,
  repository: hooks.repository,
  links: hooks.links,
  onOpenConversation: hooks.onOpenConversation,
  onOpenSupplier: hooks.onOpenSupplier,
  onSeePlans: hooks.onSeePlans,
);

/// The owner's page of a requirement. [section] (`prequal`, `invited`) and [focusBid] are where a notification or
/// a "Screen" button lands: the page opens on that part and rings that bid.
Future<void> pushRfqDetail(BuildContext context, RfqHooks hooks, String rfqId, {String? section, String? focusBid}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => rfqDetailFor(rfqId, hooks, section: section, focusBid: focusBid)),
    );

/// The supplier's page of a requirement ([section] `response` lands on the quote form).
Future<void> pushOpportunity(BuildContext context, RfqHooks hooks, String rfqId, {String? section}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => opportunityFor(rfqId, hooks, section: section)));

/// The composer: blank, editing [editId], or copying [copyFromId]. Answers
/// the requirement it posted or saved, or null when the member left.
Future<PostResult?> pushComposer(
  BuildContext context,
  RfqHooks hooks, {
  String? editId,
  String? copyFromId,
  RfqKind? kind,
}) => Navigator.of(context).push<PostResult>(
  MaterialPageRoute<PostResult>(
    builder: (route) => PostRfqScreen(
      editRfqId: editId,
      copyFromRfqId: copyFromId,
      initialKind: kind,
      repository: hooks.repository,
      links: hooks.links,
      onOpenConversation: hooks.onOpenConversation,
      onOpenSupplier: hooks.onOpenSupplier,
      onCreateCompany: hooks.onCreateCompany,
    ),
  ),
);

Future<void> pushAlerts(BuildContext context, RfqHooks hooks) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => RfqAlertsScreen(
      repository: hooks.repository,
      links: hooks.links,
      onOpenConversation: hooks.onOpenConversation,
      onOpenSupplier: hooks.onOpenSupplier,
    ),
  ),
);

Future<void> pushMyRfqs(BuildContext context, RfqHooks hooks) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => MyRfqsScreen(
      repository: hooks.repository,
      links: hooks.links,
      onOpenConversation: hooks.onOpenConversation,
      onOpenSupplier: hooks.onOpenSupplier,
      onCreateCompany: hooks.onCreateCompany,
    ),
  ),
);

Future<void> pushBoard(BuildContext context, RfqHooks hooks) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => OpenRequirementsScreen(
      repository: hooks.repository,
      links: hooks.links,
      onOpenConversation: hooks.onOpenConversation,
      onOpenSupplier: hooks.onOpenSupplier,
    ),
  ),
);

Future<void> pushMyBids(BuildContext context, RfqHooks hooks) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => MyBidsScreen(
      repository: hooks.repository,
      links: hooks.links,
      onOpenConversation: hooks.onOpenConversation,
      onOpenSupplier: hooks.onOpenSupplier,
    ),
  ),
);
