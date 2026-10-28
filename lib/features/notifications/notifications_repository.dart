import 'notification_models.dart';

/// Where the notifications come from: the API, or the designs' sample content.
abstract class NotificationsRepository {
  /// A page of the person's notifications, newest first; [unreadOnly] for the Unread tab.
  Future<NotificationPage> list({int page = 1, bool unreadOnly = false});

  /// Every unread notification, not just the latest page: the bell's dot.
  Future<int> unreadCount();

  Future<void> markRead(String id);

  /// Returns how many were read.
  Future<int> markAllRead();

  /// The person opened a record (`PATCH /notifications/seen`): whatever told
  /// them about it is read, however they got there. [kind] and [id] are the
  /// API's target kind and record id (`NotificationTarget.kind`, `recordId`).
  /// Returns how many rows were read.
  Future<int> markSeen(String kind, String id);

  /// Every category with what is on, in-app and by email.
  Future<List<NotificationPreference>> preferences();

  /// Stores one category's switches; returns the whole list as the API now has it.
  Future<List<NotificationPreference>> savePreference(NotificationPreference preference);

  /// Who is reading: their id, the company they act for, how many they belong to.
  Future<NotificationViewer> viewer();

  /// Switches the person to act for [companyId] (a fresh session), before a
  /// row about that company opens.
  Future<void> switchCompany(String companyId);
}
