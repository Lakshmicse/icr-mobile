import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../../../core/config.dart';
import '../../../core/util/links.dart';
import '../../forum/widgets/forum_sheets.dart' show confirm;
import '../account_repository.dart';
import '../api_account_repository.dart';
import '../demo_account_repository.dart';

/// The account repository a screen without one of its own blocks through: the signed-in API, or the demo.
AccountRepository blockRepositoryOf(BuildContext context) =>
    AppConfig.demo ? DemoAccountRepository() : ApiAccountRepository(api: context.read<ApiClient>());

/// "Block Asha Rao?" then the block (App Store guideline 1.2, Nov 2026), from a profile, a post, a reply, a
/// comment or a conversation. Says what a block does before it happens and confirms it after. True once blocked;
/// false when the member said Cancel or the API refused (its sentence is shown).
Future<bool> confirmBlock(
  BuildContext context, {
  required String memberId,
  required String name,
  AccountRepository? repository,
}) async {
  final repo = repository ?? blockRepositoryOf(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final sure = await confirm(
    context,
    title: 'Block $name?',
    body:
        "You won't see each other's posts, replies or profiles, and neither of you can message the other. Any follow "
        "or connection between you ends. $name won't be told.",
    action: 'Block',
  );
  if (!sure) return false;
  try {
    await repo.block(memberId);
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(ApiError.from(e).message)));
    return false;
  }
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$name is blocked. You can unblock them in Settings.')));
  return true;
}

/// "Unblock Asha Rao?" then the unblock. True once unblocked.
Future<bool> confirmUnblock(
  BuildContext context, {
  required String memberId,
  required String name,
  AccountRepository? repository,
}) async {
  final repo = repository ?? blockRepositoryOf(context);
  final sure = await confirm(
    context,
    title: 'Unblock $name?',
    body:
        "You'll see each other's posts and profiles again and can message each other. Follows and connections "
        "don't come back on their own.",
    action: 'Unblock',
  );
  if (!sure || !context.mounted) return false;
  try {
    await repo.unblock(memberId);
    return true;
  } catch (e) {
    if (context.mounted) showMessage(context, ApiError.from(e).message);
    return false;
  }
}
