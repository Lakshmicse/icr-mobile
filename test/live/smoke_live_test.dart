import 'package:flutter_test/flutter_test.dart';

import 'live.dart';

void main() {
  liveTest('the helper signs in as the emulator person', () async {
    final api = await liveClient();
    final me = await api.dio.get<Map<String, dynamic>>('/auth/me');
    expect(me.data!['email'], bharat.email);
  });
}
