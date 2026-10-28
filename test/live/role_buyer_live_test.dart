/// The BUYER / PROFESSIONAL role matrix: every member flow of the app, against the LOCAL portal API, for the four
/// accounts that belong to no company (`buyer@icr.test`, `buyer@icr.dev`, `professional@icr.test`, `guest@icr.test`).
/// What each flow did for each account is written up in `docs/ROLE_TEST_buyer.md`.
///
///     flutter test --no-pub --timeout=60s test/live/role_buyer_live_test.dart --concurrency=1
///
/// Pick one flow with `--plain-name "Home feed"`.
@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'role_buyer_account.dart';
import 'role_buyer_community.dart';
import 'role_buyer_market.dart';
import 'role_buyer_mentorship.dart';
import 'role_buyer_groups.dart';
import 'role_buyer_inbox.dart';
import 'role_buyer_jobs.dart';
import 'role_buyer_library.dart';
import 'role_buyer_learning.dart';
import 'role_buyer_market_screens.dart';
import 'role_buyer_support.dart';
import 'role_buyer_ui.dart';

void main() {
  roleBuyerCommunity();
  roleBuyerMarket();
  roleBuyerMarketScreens();
  roleBuyerJobs();
  roleBuyerLearning();
  roleBuyerMentorship();
  roleBuyerGroups();
  roleBuyerLibrary();
  roleBuyerInbox();
  roleBuyerAccount();
  roleBuyerUi();

  tearDownAll(printRoleRows);
}
