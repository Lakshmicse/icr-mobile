/// The Team page's reads against the LOCAL portal API, as the e2e company admin (`companyadmin@icr.test`, the
/// password in `irc-portal/e2e/fixtures/users.json`). READ ONLY: nothing is approved, declined, added, edited,
/// removed, invited or revoked, so the people and requests the e2e suite relies on stay as they are.
@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/team/api_team_repository.dart';
import 'package:icr_mobile/features/team/team_rules.dart';

import 'live.dart';

const _fixtureCandidates = ['../irc-portal/e2e/fixtures/users.json', 'E:/ICR/irc-portal/e2e/fixtures/users.json'];

String? _password(String email) {
  for (final path in _fixtureCandidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    for (final row in (jsonDecode(file.readAsStringSync()) as List<dynamic>).cast<Map<String, dynamic>>()) {
      if (row['email'] == email) return row['password'] as String?;
    }
  }
  return null;
}

LivePerson? get _companyAdmin {
  final password = _password('companyadmin@icr.test');
  return password == null ? null : LivePerson('companyadmin@icr.test', password, 'Chetan CompanyAdmin (COMPANY_ADMIN)');
}

void main() {
  liveTest('the company admin reads every list the Team page shows, in the shapes the app parses', () async {
    final person = _companyAdmin;
    if (person == null) {
      markTestSkipped('the e2e fixtures are not next to this package');
      return;
    }
    final client = await liveClient(person);
    final repo = ApiTeamRepository(api: client);

    final members = await repo.members();
    expect(members, isNotEmpty, reason: 'the seeded company has a team');
    expect(members.any((m) => m.role == 'COMPANY_ADMIN'), isTrue);
    for (final m in members) {
      expect(m.id, isNotEmpty);
      expect(m.name, isNotEmpty);
      expect(m.email, contains('@'));
    }
    // A role with an office carries its name; the inbox topics are the API's keys.
    final withOffice = members.where((m) => m.branchId != null);
    for (final m in withOffice) {
      expect(m.branchName, isNotNull, reason: '${m.email} has an office id and its name');
    }

    final requests = await repo.requests();
    for (final r in requests) {
      expect(r.userId, isNotEmpty);
      expect(r.name, isNotEmpty);
    }
    final adds = await repo.pendingAdds();
    for (final a in adds) {
      expect(a.userId, isNotEmpty);
    }
    final invites = await repo.invites();
    for (final i in invites) {
      expect(i.email, contains('@'));
    }

    final me = members.firstWhere((m) => m.email == person.email);
    final viewer = TeamViewer(id: me.id, role: me.role, companyId: 'live');
    expect(viewer.reachesPage, isTrue);
    expect(viewer.canManage, isTrue);

    final offices = await repo.offices(await _companyIdOf(client));
    expect(offices, isNotEmpty, reason: 'the seeded company has a head office');
    expect(offices.first.depth, 0);

    // The lookup and the people search are read-only too.
    final people = await repo.findPeople('Pooja');
    for (final p in people) {
      expect(p.name, isNotEmpty);
    }
    final lookup = await repo.lookup('nobody.at.all@example.invalid');
    expect(lookup.onIcr, isFalse);
    expect(lookup.alreadyMember, isFalse);
  });
}

Future<String> _companyIdOf(dynamic client) async {
  final res = await client.dio.get<Map<String, dynamic>>('/me/companies');
  final companies = (res.data!['companies'] as List).cast<Map<String, dynamic>>();
  return companies.firstWhere((c) => c['active'] == true)['companyId'] as String;
}
