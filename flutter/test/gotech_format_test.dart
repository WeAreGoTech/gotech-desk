import 'package:flutter_hbb/desktop/widgets/gotech_peer_format.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gotech_fixtures.dart';

void main() {
  group('goTechNormalize', () {
    test('folds Turkish letters and case', () {
      expect(goTechNormalize('DİLEK ŞİRKETİ ÇĞÖÜ Iı'), 'dilek sirketi cgou ii');
    });
  });

  group('goTechMatches', () {
    bool m(String q, GoTechPeerInfo p) => p.matches(q);
    final dilara = kFixturePeers.firstWhere((p) => p.alias == 'Dilara Aydın');
    final emre = kFixturePeers.firstWhere((p) => p.alias == 'Emre Koç');
    final testPc = kFixturePeers.firstWhere((p) => p.id == '229814507');

    test('alias, hostname and company, Turkish-insensitive', () {
      expect(m('dilara aydin', dilara), isTrue);
      expect(m('dilek-ofis', dilara), isTrue);
      expect(m('dilek tibbi', emre), isTrue);
      expect(m('DEPO', emre), isTrue);
      expect(m('zzz', emre), isFalse);
    });

    test('digits match the ID with spaces ignored', () {
      expect(m('229 814', testPc), isTrue);
      expect(m('2298 14507', testPc), isTrue);
      expect(m('229 815', testPc), isFalse);
    });

    test('empty query matches everything', () {
      expect(m('  ', testPc), isTrue);
    });
  });

  group('row texts', () {
    test('alias equal to hostname counts as no name', () {
      const p = GoTechPeerInfo(id: '1', alias: 'ykm-srv', hostname: 'YKM-SRV');
      expect(goTechPeerTitle(p), 'YKM-SRV');
      expect(goTechPeerDetail(p), kGoTechNoName);
    });

    test('named person shows the hostname below', () {
      const p = GoTechPeerInfo(id: '1', alias: 'Kasa', hostname: 'KMA-KASA');
      expect(goTechPeerTitle(p), 'Kasa');
      expect(goTechPeerDetail(p), 'KMA-KASA');
    });

    test('no alias and no hostname shows the ID', () {
      const p = GoTechPeerInfo(id: '229814507');
      expect(goTechPeerTitle(p), '229 814 507');
    });
  });

  group('goTechLastSeenText', () {
    String t(Duration ago) =>
        goTechLastSeenText(kFixtureNow.subtract(ago), now: kFixtureNow);

    test('relative Turkish times', () {
      expect(goTechLastSeenText(null, now: kFixtureNow), kGoTechNoValue);
      expect(t(const Duration(seconds: 20)), 'Az önce');
      expect(t(const Duration(minutes: 5)), '5 dk önce');
      expect(t(const Duration(hours: 2)), '2 saat önce');
      expect(t(const Duration(hours: 21, minutes: 18)), 'Dün 17:42');
      expect(t(const Duration(days: 4)), '4 gün önce');
      expect(t(const Duration(days: 12)), '12 Kas');
      expect(t(const Duration(days: 400)), '20 Eki 2025');
    });

    test('parses the panel ISO 8601 value in local time', () {
      final utc = kFixtureNow.toUtc().subtract(const Duration(hours: 3));
      expect(
          goTechLastSeenText(DateTime.parse(utc.toIso8601String()),
              now: kFixtureNow),
          '3 saat önce');
    });
  });

  group('goTechConnectItems', () {
    List<GoTechConnectItem> items(String q) => goTechConnectItems(q,
        peers: kFixturePeers, companies: fixtureCompanyCounts());

    test('a short ID lists matching computers, the recent one first', () {
      final r = items('2298');
      expect(r.map((e) => e.kind), everyElement(GoTechConnectKind.peer));
      expect(r.map((e) => e.id), ['229871230', '229814507']);
    });

    test('a full ID starts with a direct connect', () {
      final r = items('229 814 507');
      expect(r.first.kind, GoTechConnectKind.direct);
      expect(r.first.id, '229814507');
      expect(r[1].id, '229814507');
    });

    test('a name lists computers, then companies', () {
      final r = items('dil');
      expect(r.first.peer!.alias, 'Dilara Aydın');
      expect(r.last.kind, GoTechConnectKind.company);
      expect(r.last.company, kDilek);
      expect(r.last.companyCount, 2);
    });

    test('caps computers at six and companies at four', () {
      final r = items('e');
      expect(r.where((e) => e.kind == GoTechConnectKind.peer).length,
          kGoTechMaxPeerSuggestions);
      expect(r.where((e) => e.kind == GoTechConnectKind.company).length,
          kGoTechMaxCompanySuggestions);
    });
  });
}
