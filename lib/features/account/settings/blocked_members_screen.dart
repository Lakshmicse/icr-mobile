import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../account_models.dart';
import '../account_repository.dart';
import '../api_account_repository.dart';
import '../demo_account_repository.dart';
import '../members/block_member.dart';
import '../widgets/account_kit.dart';

/// Settings → Blocked Members (App Store guideline 1.2, Nov 2026): everyone the member blocked, each with Unblock.
class BlockedMembersScreen extends StatefulWidget {
  const BlockedMembersScreen({super.key, this.repository, this.onBack});

  final AccountRepository? repository;
  final VoidCallback? onBack;

  @override
  State<BlockedMembersScreen> createState() => _BlockedMembersScreenState();
}

class _BlockedMembersScreenState extends State<BlockedMembersScreen> {
  late final AccountRepository _repository;
  List<BlockedMember>? _rows;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        (AppConfig.demo ? DemoAccountRepository() : ApiAccountRepository(api: context.read<ApiClient>()));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _repository.blockedMembers();
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unblock(BlockedMember m) async {
    final done = await confirmUnblock(context, memberId: m.id, name: m.name, repository: _repository);
    if (done && mounted) setState(() => _rows = [...?_rows?.where((r) => r.id != m.id)]);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AccountBar(title: 'Blocked Members', onBack: widget.onBack),
      body: rows == null
          ? (_loading || _error == null
                ? const AccountLoading()
                : AccountError(message: _error!, onRetry: _load))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 28),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Text(
                      "Members you block can't see your posts or profile, or message you, and you don't see theirs. "
                      "They aren't told.",
                      style: AccountText.meta,
                    ),
                  ),
                  AccountCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: rows.isEmpty
                        ? const Padding(
                            key: Key('blocked.none'),
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: AccountEmpty(text: "You haven't blocked anyone."),
                          )
                        : Column(
                            children: [
                              for (final m in rows)
                                Padding(
                                  key: Key('blocked.${m.id}'),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      AccountAvatar(url: m.avatarUrl, initials: _initials(m), size: 40),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(m.name, style: AccountText.itemTitle, overflow: TextOverflow.ellipsis),
                                            if (m.headline != null)
                                              Text(m.headline!, style: AccountText.meta, overflow: TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        key: Key('blocked.unblock.${m.id}'),
                                        onPressed: () => _unblock(m),
                                        child: const Text('Unblock'),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  static String _initials(BlockedMember m) {
    final f = m.firstName.isNotEmpty ? m.firstName[0] : '';
    final l = m.lastName.isNotEmpty ? m.lastName[0] : '';
    return '$f$l'.toUpperCase();
  }
}
