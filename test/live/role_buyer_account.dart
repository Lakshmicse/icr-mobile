/// Role matrix, part 9: the person's profile, a member's public page, Settings, Saved items, Network and Contact for
/// the four accounts that belong to no company. Every edit is put back as it was (a role added is removed, an About
/// written is restored, a résumé a first edit created for an account that had none is deleted); the account is never
/// deleted.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/features/account/account_models.dart';
import 'package:icr_mobile/features/account/api_account_repository.dart';
import 'package:icr_mobile/features/account/members/member_profile_screen.dart';
import 'package:icr_mobile/features/account/profile/my_profile_screen.dart';
import 'package:icr_mobile/features/account/saved/saved_items_screen.dart';
import 'package:icr_mobile/features/account/saved/saved_models.dart';
import 'package:icr_mobile/features/account/saved/saved_repository.dart';
import 'package:icr_mobile/features/account/settings/notification_preferences_screen.dart';
import 'package:icr_mobile/features/account/settings/security_screen.dart';
import 'package:icr_mobile/features/account/settings/settings_screen.dart';
import 'package:icr_mobile/features/contact/api_contact_repository.dart';
import 'package:icr_mobile/features/contact/contact_controller.dart';
import 'package:icr_mobile/features/contact/contact_models.dart';
import 'package:icr_mobile/features/contact/contact_screen.dart';
import 'package:icr_mobile/features/marketplace/api_marketplace_repository.dart';
import 'package:icr_mobile/features/marketplace/marketplace_filters.dart';
import 'package:icr_mobile/features/network/api_network_repository.dart';
import 'package:icr_mobile/features/network/network_controller.dart';
import 'package:icr_mobile/features/network/network_screen.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';
import 'career_live_support.dart';
import 'live.dart';
import 'role_buyer_support.dart';

final _accounts = <String, ApiAccountRepository>{};
ApiAccountRepository accountOf(Who w) => _accounts.putIfAbsent(w.email, () => ApiAccountRepository(api: w.api));

void roleBuyerAccount() {
  setUpAll(loadAppFonts);

  group('Profile', () {
    liveTest('the profile, its lists and the pickers read for every account', () async {
      for (final w in await everyone()) {
        final repo = accountOf(w);
        final me = await repo.myProfile();
        expect(me.email, w.email);
        await repo.experience();
        await repo.education();
        await repo.careerBreaks();
        await repo.links();
        await repo.credentials();
        expect(await repo.jobTitles(), isNotEmpty);
        expect(await repo.cities(), isNotEmpty);
        expect((await repo.searchCompanies('a')), isNotNull);
        record('Profile: sections, pickers (read)', w.person, 'works', 'completeness ${me.completeness.score}');
      }
    });

    liveTest('About, a role, a degree and skills are written, read back and put back for every account', () async {
      for (final w in await everyone()) {
        final repo = accountOf(w);
        final before = await repo.myProfile();
        final roles = await repo.experience();
        final degrees = await repo.education();
        // The first About or skills an account saves creates its default résumé, and the API refuses to delete a
        // default résumé ("This is your default résumé"): so an account with none has the roles and degrees tried but
        // not the About, and keeps the state the e2e suite expects. Set ROLE_BUYER_WRITE_RESUME=1 to try it too.
        final writeResume = before.hasResume || Platform.environment['ROLE_BUYER_WRITE_RESUME'] == '1';
        try {
          if (writeResume) {
            final about = 'Role matrix: a line about ${w.first}, put back straight after.';
            final saved = await described('About', () => repo.updateResume({'summary': about}));
            expect(saved.summary, about, reason: '${w.email}: the About is kept');
            expect((await repo.myProfile()).summary, about);
            final skilled = await described(
              'skills',
              () => repo.updateResume({
                'skills': ['Role matrix'],
              }),
            );
            expect(skilled.skills, contains('Role matrix'));
          }

          // A role, then the list as it was.
          final role = Experience(
            title: 'Role matrix tester',
            organisation: 'Role Matrix Co',
            startYear: 2020,
            endYear: 2021,
          );
          final withRole = await described('add a role', () => repo.saveExperience([...roles, role]));
          expect(withRole.map((r) => r.title), contains('Role matrix tester'));
          expect((await repo.experience()).map((r) => r.title), contains('Role matrix tester'));
          await described('restore the roles', () => repo.saveExperience(roles));

          // A degree, then the list as it was.
          final degree = Education(
            institution: 'Role Matrix Institute',
            degree: 'B.Sc.',
            startYear: 2015,
            endYear: 2018,
          );
          final withDegree = await described('add a degree', () => repo.saveEducation([...degrees, degree]));
          expect(withDegree.map((d) => d.institution), contains('Role Matrix Institute'));
          await described('restore the degrees', () => repo.saveEducation(degrees));
          record(
            'Profile: About, a role, a degree, skills (edit, read back, put back)',
            w.person,
            'works',
            writeResume
                ? ''
                : 'roles and degrees only: the first About would create a default resume the API cannot delete',
          );
        } finally {
          if (writeResume && before.hasResume) {
            await described(
              'restore About and skills',
              () => repo.updateResume({'summary': before.summary ?? '', 'skills': before.skills}),
            );
          }
          await described('restore roles', () => repo.saveExperience(roles));
          await described('restore degrees', () => repo.saveEducation(degrees));
        }
        final after = await repo.myProfile();
        expect(after.summary ?? '', before.summary ?? '', reason: '${w.email}: the About is as it was');
        expect(after.hasResume, before.hasResume, reason: '${w.email}: no resume was created');
      }
    });

    liveTest('a member\'s public page reads, and Follow, Message and the posts work, for every account', () async {
      final people = await everyone();
      for (var i = 0; i < people.length; i++) {
        final w = people[i];
        final other = people[(i + 1) % people.length];
        final repo = accountOf(w);
        final member = await repo.member(other.id);
        expect(member, isNotNull);
        await repo.memberPosts(other.id);
        final was = (await repo.member(other.id)).follow.viewerFollows;
        if (was) {
          await repo.unfollow(other.id);
          expect((await repo.member(other.id)).follow.viewerFollows, isFalse);
          await repo.follow(other.id);
        } else {
          await repo.follow(other.id);
          expect((await repo.member(other.id)).follow.viewerFollows, isTrue);
          await repo.unfollow(other.id);
        }
        expect((await repo.member(other.id)).follow.viewerFollows, was, reason: 'Follow is put back as it was');
        final thread = await repo.startConversation(other.id);
        expect(thread, isNotEmpty);
        record('Member page: read, follow, unfollow, message', w.person, 'works', 'two-person with ${other.first}');
      }
    });
  });

  group('Settings', () {
    liveTest(
      'the language is saved and put back, preferences switch and restore, the data export and the security page read',
      () async {
        for (final w in await everyone()) {
          final repo = accountOf(w);
          final before = await repo.accountLocale();
          try {
            await repo.updateMe({'locale': 'hi'});
            expect(await repo.accountLocale(), 'hi');
          } finally {
            await repo.updateMe({'locale': before});
          }
          expect(await repo.accountLocale(), before, reason: '${w.email}: the language is as it was');

          final prefs = await repo.notificationPreferences();
          expect(prefs, isNotEmpty);
          final row = prefs.firstWhere((p) => !p.locked);
          try {
            final saved = await repo.saveNotificationPreferences([row.copyWith(email: !row.email)]);
            expect(saved.firstWhere((p) => p.category == row.category).email, !row.email);
          } finally {
            await repo.saveNotificationPreferences([row]);
          }
          expect(
            (await repo.notificationPreferences()).firstWhere((p) => p.category == row.category).email,
            row.email,
            reason: '${w.email}: the switch is as it was',
          );

          final export = await repo.exportData();
          expect(export, isNotEmpty);
          expect('$export', contains(w.email), reason: 'the export is this person\'s own data');
          await repo.myCompanies();
          record('Settings: language, notification switches, download my data, companies', w.person, 'works');
        }
      },
    );
  });

  group('Saved items, Network and Contact', () {
    liveTest(
      'every shelf of Saved items reads, and a supplier saved in the Marketplace appears there and can be taken off',
      () async {
        for (final w in await everyone()) {
          final saved = ApiSavedRepository(api: w.api);
          for (final kind in SavedKind.values) {
            final page = await saved.load(kind);
            expect(page.total, greaterThanOrEqualTo(0), reason: '${w.email}: ${kind.label}');
          }
          final market = ApiMarketplaceRepository(api: w.api);
          final supplier = (await market.suppliers(const MarketplaceFilters())).suppliers.first;
          final was = (await market.savedIds()).contains(supplier.id);
          if (!was) await market.setSaved(supplier.id, true);
          try {
            final shelf = await saved.load(SavedKind.suppliers);
            final item = shelf.items.firstWhere(
              (i) => i.id == supplier.id,
              orElse: () => throw StateError('not on the shelf'),
            );
            await saved.unsave(item);
            expect((await market.savedIds()).contains(supplier.id), isFalse, reason: 'taken off from Saved items');
            await saved.save(item);
            expect((await market.savedIds()).contains(supplier.id), isTrue);
          } finally {
            await market.setSaved(supplier.id, was);
          }
          record('Saved items: shelves, save and un-save a supplier', w.person, 'works');
        }
      },
    );

    liveTest('Network: the feed, suggestions, following and followers read, and a follow is put back', () async {
      for (final w in await everyone()) {
        final repo = ApiNetworkRepository(api: w.api);
        await repo.feed();
        final suggestions = await repo.suggestions();
        await repo.following();
        await repo.followers(w.id);
        final target = suggestions.firstWhere((p) => p.id != w.id, orElse: () => throw StateError('no one to follow'));
        await repo.follow(target.id);
        await repo.unfollow(target.id);
        record('Network: feed, suggestions, following, followers, follow', w.person, 'works');
      }
    });

    liveTest(
      'Contact: the form is filled from the account and a message goes through (taken out of the inbox by staff)',
      () async {
        final people = await everyone();
        final w = people[2];
        final repo = ApiContactRepository(api: w.api);
        final sender = await repo.sender();
        expect(sender?.email, w.email);
        final marker = 'role-matrix-${DateTime.now().millisecondsSinceEpoch}';
        try {
          final ref = await repo.send(
            ContactMessage(
              name: sender!.name,
              email: sender.email,
              topic: ContactTopic.other,
              message: 'Role matrix, please ignore: $marker',
            ),
          );
          expect(ref, isNotEmpty);
          record('Contact: send a message', w.person, 'works', 'a contact message, put away by staff');
        } finally {
          await putAwayContact(marker, topic: 'OTHER');
        }
        for (final p in people.where((p) => p.email != w.email)) {
          expect((await ApiContactRepository(api: p.api).sender())?.email, p.email);
          record('Contact: the form starts from the account', p.person, 'works');
        }
      },
    );
  });

  group('the account screens, drawn for every account', () {
    testWidgets(
      'the profile, a member page, Settings, security, preferences, Saved items, Network and Contact draw',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        final people = (await tester.runAsync(everyone))!;
        for (var i = 0; i < people.length; i++) {
          final w = people[i];
          final other = people[(i + 1) % people.length];
          final client = [Provider<ApiClient>.value(value: w.api)];
          const size = Size(390, 2600);
          final repo = accountOf(w);

          await loadScreen(
            tester,
            MyProfileScreen(repository: repo),
            appProviders: client,
            size: size,
          );
          var text = expectHealthy(tester, 'the profile as ${w.email}');
          expect(text, contains(w.first));
          expect(text, contains('Experience'));
          await unmount(tester);

          await loadScreen(
            tester,
            MemberProfileScreen(userId: other.id, repository: repo),
            appProviders: client,
            size: size,
          );
          text = expectHealthy(tester, 'a member page as ${w.email}');
          expect(text, contains(other.first));
          await unmount(tester);

          await loadScreen(
            tester,
            SettingsScreen(repository: repo),
            appProviders: client,
            size: size,
          );
          text = expectHealthy(tester, 'Settings as ${w.email}');
          expect(text, contains('Sign out'));
          expect(text, contains('Download my data'));
          await unmount(tester);

          await loadScreen(
            tester,
            SignInSecurityScreen(repository: repo),
            appProviders: client,
            size: size,
          );
          text = expectHealthy(tester, 'Sign-in and security as ${w.email}');
          expect(text, contains(w.email));
          await unmount(tester);

          await loadScreen(
            tester,
            NotificationPreferencesScreen(repository: repo),
            appProviders: client,
            size: size,
          );
          expectHealthy(tester, 'notification preferences as ${w.email}');
          await unmount(tester);

          await loadScreen(
            tester,
            SavedItemsScreen(repository: ApiSavedRepository(api: w.api)),
            appProviders: client,
            size: size,
          );
          text = expectHealthy(tester, 'Saved items as ${w.email}');
          expect(text, contains('Jobs'));
          await unmount(tester);

          final network = NetworkController(ApiNetworkRepository(api: w.api));
          await loadScreen(
            tester,
            NetworkScreen(),
            providers: [ChangeNotifierProvider<NetworkController>.value(value: network)],
            appProviders: client,
            size: size,
          );
          expectHealthy(tester, 'Network as ${w.email}');
          await unmount(tester);

          final contact = ContactController(ApiContactRepository(api: w.api));
          await loadScreen(
            tester,
            ContactScreen(),
            providers: [ChangeNotifierProvider<ContactController>.value(value: contact)],
            appProviders: client,
            size: size,
          );
          text = expectHealthy(tester, 'Contact as ${w.email}');
          expect(find.text(w.email), findsOneWidget, reason: 'the form is filled from the account');
          await unmount(tester);
          record('Profile, member page, Settings, Saved items, Network, Contact: screens', w.person, 'works');
        }
      },
    );
  });
}
