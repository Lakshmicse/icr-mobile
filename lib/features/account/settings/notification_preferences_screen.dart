import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../account_labels.dart';
import '../account_models.dart';
import '../account_repository.dart';
import '../api_account_repository.dart';
import '../demo_account_repository.dart';
import '../widgets/account_kit.dart';

/// The notification preferences: for each kind of update, whether ICR tells the
/// person in the app and whether it also emails them. A switch saves the moment
/// it is touched and goes back, with the API's sentence, when it is refused.
/// Receipts, support replies and security notices are always sent: their
/// switches are drawn on and cannot be changed.
class NotificationPreferencesController extends ChangeNotifier {
  NotificationPreferencesController(this.repository);

  final AccountRepository repository;

  List<NotificationPreference>? rows;
  bool loading = true;
  String? loadError;

  /// The categories whose change is on its way.
  final Set<String> saving = {};

  /// What the last change was refused with.
  String? actionError;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load({bool refresh = false}) async {
    if (!refresh || rows == null) {
      loading = true;
      loadError = null;
      _notify();
    }
    try {
      rows = await repository.notificationPreferences();
      loadError = null;
    } catch (e) {
      if (rows == null || !refresh) {
        loadError = ApiError.from(e).message;
      } else {
        actionError = ApiError.from(e).message;
      }
    } finally {
      loading = false;
      _notify();
    }
  }

  /// Turns the in-app or email switch of [category] on or off.
  Future<bool> set(String category, {bool? inApp, bool? email}) async {
    final all = rows;
    if (all == null || saving.contains(category)) return false;
    final at = all.indexWhere((r) => r.category == category);
    if (at < 0 || all[at].locked) return false;
    final was = all[at];
    final next = was.copyWith(inApp: inApp, email: email);
    rows = [...all]..[at] = next;
    saving.add(category);
    actionError = null;
    _notify();
    try {
      final saved = await repository.saveNotificationPreferences([next]);
      // The API answers every row as it now stands.
      if (saved.isNotEmpty) rows = saved;
      return true;
    } catch (e) {
      rows = [...rows!]..[rows!.indexWhere((r) => r.category == category)] = was;
      actionError = ApiError.from(e).message;
      return false;
    } finally {
      saving.remove(category);
      _notify();
    }
  }

  void dismissError() {
    actionError = null;
    _notify();
  }
}

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key, this.repository, this.onBack});

  final AccountRepository? repository;
  final VoidCallback? onBack;

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  late final NotificationPreferencesController _c;

  @override
  void initState() {
    super.initState();
    _c = NotificationPreferencesController(
      widget.repository ?? (AppConfig.demo ? DemoAccountRepository() : ApiAccountRepository(api: context.read<ApiClient>())),
    )..load();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AccountBar(title: 'Notifications', onBack: widget.onBack),
      body: ListenableBuilder(
        listenable: _c,
        builder: (context, _) {
          final rows = _c.rows;
          if (rows == null) {
            if (_c.loading) return const AccountLoading();
            return AccountError(message: _c.loadError ?? 'Try again in a moment.', onRetry: _c.load);
          }
          return RefreshIndicator(
            onRefresh: () => _c.load(refresh: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 12, bottom: 28),
              children: [
                if (_c.actionError != null)
                  Container(
                    key: const Key('prefs.error'),
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(_c.actionError!, style: AccountText.error.copyWith(fontSize: 14))),
                        IconButton(
                          tooltip: 'Dismiss',
                          onPressed: _c.dismissError,
                          icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.slate500),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Text(
                    'Choose how ICR tells you about each kind of update: in the app, and by email.',
                    style: AccountText.meta,
                  ),
                ),
                AccountCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 4),
                        child: Row(
                          children: [
                            const Spacer(),
                            SizedBox(width: 64, child: Center(child: Text('In app', style: AccountText.meta.copyWith(fontWeight: FontWeight.w600)))),
                            SizedBox(width: 64, child: Center(child: Text('Email', style: AccountText.meta.copyWith(fontWeight: FontWeight.w600)))),
                          ],
                        ),
                      ),
                      for (final (i, r) in rows.indexed) _row(r, divider: i > 0),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(NotificationPreference r, {required bool divider}) {
    final words = notificationCategories[r.category];
    final busy = _c.saving.contains(r.category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (divider) const Divider(height: 1, thickness: 1, color: AppColors.slate100),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(words?.$1 ?? r.category, style: AccountText.itemTitle),
                    if (words != null) Text(words.$2, style: AccountText.meta.copyWith(fontSize: 13)),
                    if (r.locked) Text('Always sent', style: AccountText.meta.copyWith(fontSize: 13, color: AppColors.slate400)),
                  ],
                ),
              ),
              SizedBox(
                width: 64,
                child: Switch(
                  key: Key('pref.${r.category}.inApp'),
                  value: r.inApp,
                  onChanged: r.locked || busy ? null : (v) => _c.set(r.category, inApp: v),
                ),
              ),
              SizedBox(
                width: 64,
                child: Switch(
                  key: Key('pref.${r.category}.email'),
                  value: r.email,
                  onChanged: r.locked || busy ? null : (v) => _c.set(r.category, email: v),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
