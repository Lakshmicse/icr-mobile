import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/config.dart';
import '../../core/util/links.dart';
import '../notifications/notification_scope.dart';
import 'api_messaging_repository.dart';
import 'attachment_picker.dart';
import 'conversation_screen.dart';
import 'demo_messaging_repository.dart';
import 'inbox_screen.dart';
import 'messaging_models.dart';
import 'messaging_repository.dart';

/// Picks a photo or a file to send (the paperclip). The default is the phone's
/// own picker, `pickDeviceAttachment` (`file_picker`); null means "chose nothing".
typedef AttachmentPicker = Future<PickedAttachment?> Function(BuildContext context);

/// How other screens open Messages. Each "Message" button opens its thread
/// through the record's own endpoint, as the website does (a supplier's sales
/// inbox, a job's hiring contact, a pairing's or a purchase's thread), then
/// pushes the conversation. A refusal is shown as the API words it, and the
/// call returns false.
abstract final class MessagingLauncher {
  /// What the composer's paperclip uses: the phone's picker. Set it to null to take the paperclip away.
  static AttachmentPicker? attachmentPicker = pickDeviceAttachment;

  static DemoMessagingRepository? _demo;

  /// The repository the screens use: one provided above them (tests, the
  /// demo), else the API with the signed-in person's session.
  static MessagingRepository repositoryOf(BuildContext context) {
    final provided = Provider.of<MessagingRepository?>(context, listen: false);
    if (provided != null) return provided;
    if (AppConfig.demo) return _demo ??= DemoMessagingRepository();
    return ApiMessagingRepository(api: context.read<ApiClient>(), viewerId: viewerIdOf(context));
  }

  /// The signed-in person's id, when the session knows it.
  static String? viewerIdOf(BuildContext context) => Provider.of<AuthController?>(context, listen: false)?.user?.id;

  /// The inbox; [inbox] opens a company's (its id) instead of the person's own.
  static Future<void> openInbox(BuildContext context, {String? inbox, MessagingRepository? repository}) {
    final scope = NotificationScope.of(context);
    return Navigator.of(context).push(scope.route<void>(InboxScreen(initialInbox: inbox, repository: repository)));
  }

  /// One conversation. [asCompanyId] reads it from that company's inbox;
  /// [focusMessageId] scrolls to one message.
  static Future<void> openConversation(
    BuildContext context,
    String conversationId, {
    String? asCompanyId,
    String? focusMessageId,
    Conversation? initial,
    MessagingRepository? repository,
    AttachmentPicker? pickAttachment,
  }) {
    final scope = NotificationScope.of(context);
    return Navigator.of(context).push(
      scope.route<void>(
        ConversationScreen(
          conversationId: conversationId,
          asCompanyId: asCompanyId,
          focusMessageId: focusMessageId,
          initial: initial,
          repository: repository,
          pickAttachment: pickAttachment,
        ),
      ),
    );
  }

  /// A plain conversation with one person (reused when the two share one).
  static Future<bool> withPerson(BuildContext context, String userId, {String? message}) =>
      _open(context, (r) => r.startWithPerson(userId, message: message));

  /// "Send Message" on a supplier: by its listing ([vendorId]) through the
  /// supplier endpoint (optionally about a requirement, [rfqId]), or by its
  /// company ([companyId]) to that company's sales inbox.
  static Future<bool> withSupplier(
    BuildContext context, {
    String? vendorId,
    String? companyId,
    String? rfqId,
    String? message,
  }) {
    assert(vendorId != null || companyId != null, 'Name the supplier by its listing or its company');
    if (vendorId != null) {
      return _open(context, (r) => r.startWithSupplier(vendorId, rfqId: rfqId, message: message));
    }
    return _open(context, (r) => r.startWithCompany(companyId!, 'SALES', message: message));
  }

  /// "Message" on a company page, about a topic: `SALES`, `CAREERS`, `PARTNERSHIP` or `GENERAL`.
  static Future<bool> withCompany(
    BuildContext context,
    String companyId, {
    String topic = 'GENERAL',
    String? message,
  }) => _open(context, (r) => r.startWithCompany(companyId, topic, message: message));

  /// "Message" on a job: its hiring contact, picked by the API.
  static Future<bool> forJob(BuildContext context, String jobId, {String? message}) =>
      _open(context, (r) => r.startWithJobContact(jobId, message: message));

  /// A mentor-service purchase: a consultation's own thread, else the pair's.
  static Future<bool> forPurchase(BuildContext context, String purchaseId) =>
      _open(context, (r) => r.openForPurchase(purchaseId));

  /// A mentoring pairing's thread.
  static Future<bool> forMentorship(BuildContext context, String mentorshipId) =>
      _open(context, (r) => r.openForMentorship(mentorshipId));

  /// A group session's room.
  static Future<bool> forGroupSession(BuildContext context, String sessionId) =>
      _open(context, (r) => r.openForGroupSession(sessionId));

  /// A requirement's thread: a supplier opens its own with the buying team;
  /// the buying team names the supplier company ([supplierCompanyId]).
  static Future<bool> forRfq(BuildContext context, String rfqId, {String? supplierCompanyId}) =>
      _open(context, (r) => r.openForRfq(rfqId, supplierCompanyId: supplierCompanyId));

  /// An employer's thread with an applicant.
  static Future<bool> forApplication(BuildContext context, String applicationId) =>
      _open(context, (r) => r.openForApplication(applicationId));

  static bool _busy = false;

  static Future<bool> _open(BuildContext context, Future<String> Function(MessagingRepository r) start) async {
    if (_busy) return false;
    _busy = true;
    final repository = repositoryOf(context);
    final scope = NotificationScope.of(context);
    final navigator = Navigator.of(context);
    try {
      final id = await start(repository);
      if (!context.mounted) return false;
      // Opened: the caller hears so now, not when the person comes back.
      unawaited(navigator.push(scope.route<void>(ConversationScreen(conversationId: id, repository: repository))));
      return true;
    } catch (e) {
      if (context.mounted) showMessage(context, ApiError.from(e).message);
      return false;
    } finally {
      _busy = false;
    }
  }
}
