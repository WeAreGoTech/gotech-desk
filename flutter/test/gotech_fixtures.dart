import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/desktop/widgets/gotech_peer_format.dart';
import 'package:flutter_hbb/desktop/widgets/gotech_sidebar_view.dart';
import 'package:flutter_hbb/desktop/widgets/gotech_table_view.dart';
import 'package:flutter_hbb/desktop/widgets/gotech_tokens.dart';
import 'package:flutter_hbb/desktop/widgets/gotech_view_parts.dart';

// Invented address book for the GoTech widget tests. No real customers, people or IDs.

final kFixtureNow = DateTime(2026, 11, 24, 15, 0);

const kTeam = 'GoTech ekibi';
const kYildiz = 'YILDIZ KALIP MAK. YED. PARÇA SAN. TİC. LTD. ŞTİ.';
const kAkdeniz = 'AKDENİZ TURİZM ENERJİ İNŞ. SAN. TİC. A.Ş.';
const kKuzey = 'Kuzey Motorlu Araçlar';
const kDilek = 'DİLEK TIBBİ ÜRÜNLER SAN. VE TİC. LTD. ŞTİ.';
const kOrnek = 'Örnek Test';
const kSevgi = 'SEVGİ DERİ SAN. VE TİC. LTD. ŞTİ.';

const kCompanyColors = {
  kTeam: Color(0xFF4C8DF6),
  kYildiz: Color(0xFF5BB65F),
  kAkdeniz: Color(0xFFF0A23B),
  kKuzey: Color(0xFFA35BD0),
  kDilek: Color(0xFF6068DA),
  kOrnek: Color(0xFFE2533F),
  kSevgi: Color(0xFF9A9BA1),
};

Color companyColor(String c) => kCompanyColors[c] ?? Colors.grey;

GoTechPeerInfo _p(String id, String alias, String host, String co,
        {bool on = false,
        bool recent = false,
        Duration? ago,
        String platform = 'Windows'}) =>
    GoTechPeerInfo(
      id: id,
      alias: alias,
      hostname: host,
      tags: [co],
      platform: platform,
      online: on,
      recent: recent,
      lastSeen: ago == null ? null : kFixtureNow.subtract(ago),
    );

final kFixturePeers = [
  _p('318402776', 'Ahmet Yılmaz', 'AHMET-MBP', kTeam,
      on: true, platform: 'Mac OS'),
  _p('318455120', 'Cem Kara', 'CEM-PC', kTeam, on: true),
  _p('401552310', 'Murat Kaya', 'MUHASEBE-01', kYildiz, on: true, recent: true),
  _p('401552377', 'Serkan Öztürk', 'URETIM-PC', kYildiz,
      ago: const Duration(hours: 21, minutes: 18)),
  _p('401553012', 'YKM-SRV', 'YKM-SRV', kYildiz, on: true),
  _p('512870034', 'Elif Şahin', 'RESEPSIYON-1', kAkdeniz, on: true),
  _p('512870551', 'Burak Demir', 'AKD-LAPTOP', kAkdeniz,
      ago: const Duration(days: 4)),
  _p('623020116', 'Zeynep Arslan', 'SATIS-02', kKuzey, on: true),
  _p('623019874', 'Hakan Deniz', 'SERVIS-MASA', kKuzey,
      recent: true, ago: const Duration(hours: 2)),
  _p('623020448', 'Kasa', 'KMA-KASA', kKuzey, ago: const Duration(days: 12)),
  _p('734551207', 'Dilara Aydın', 'DILEK-OFIS', kDilek, on: true, recent: true),
  _p('734551893', 'Emre Koç', 'DEPO-PC', kDilek,
      ago: const Duration(hours: 29, minutes: 45)),
  _p('229814507', '', 'TEST-PC', kOrnek, ago: const Duration(days: 67)),
  _p('229871230', 'Ayşe Test', 'TEST-PC2', kOrnek,
      recent: true, ago: const Duration(days: 69)),
  _p('845102366', 'Mehmet Sevgi', 'SEVGI-PATRON', kSevgi, on: true),
  _p('845102790', 'Atölye', 'ATOLYE-PC', kSevgi, ago: const Duration(days: 3)),
];

Map<String, int> fixtureCompanyCounts() => {
      for (final c in kCompanyColors.keys)
        c: kFixturePeers.where((p) => p.company == c).length,
    };

List<GoTechCompanyData> fixtureCompanies(String query) => [
      for (final c in kCompanyColors.keys)
        () {
          final n = kFixturePeers
              .where((p) => p.company == c && p.matches(query))
              .length;
          return GoTechCompanyData(
              tag: c,
              name: c,
              color: companyColor(c),
              count: n,
              dim: query.isNotEmpty && n == 0);
        }(),
    ];

GoTechRowData fixtureRow(GoTechPeerInfo p, {required bool showCompany}) =>
    GoTechRowData(
      title: goTechPeerTitle(p),
      detail: goTechPeerDetail(p),
      company: showCompany ? p.company : '',
      companyColor: showCompany ? companyColor(p.company) : null,
      idText: formatID(p.id),
      seenText: p.online
          ? kGoTechOnlineText
          : goTechLastSeenText(p.lastSeen, now: kFixtureNow),
      online: p.online,
      platformIcon: Icon(
          p.platform == 'Mac OS' ? Icons.apple : Icons.window_rounded,
          size: kGoTechPlatformIconSize,
          color: Colors.grey),
    );

/// Stand-in for the connect row (ID field, red "Bağlan", chevron), which needs the native bridge.
class FakeConnectRow extends StatelessWidget {
  final String text;
  final bool focused;
  const FakeConnectRow({super.key, required this.text, this.focused = false});

  @override
  Widget build(BuildContext context) {
    final c = GoTechColors.of(context);
    BoxDecoration box(Color border) => BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: focused ? 1.5 : 1));
    return SizedBox(
      height: 48,
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: box(focused ? kGoTechRed : c.line),
            child: Row(children: [
              Icon(Icons.desktop_windows_outlined, size: 20, color: c.muted),
              const SizedBox(width: 12),
              Text(text, style: const TextStyle(fontSize: 20)),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: kGoTechRed, borderRadius: BorderRadius.circular(12)),
          child: const Text('Bağlan',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ),
        const SizedBox(width: 8),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.expand_more_rounded, size: 18, color: c.fg),
        ),
      ]),
    );
  }
}

/// Stand-in for the list toolbar (search, "Sadece çevrimiçi", sort, "⋯").
class FakeToolbar extends StatelessWidget {
  final String query;
  const FakeToolbar({super.key, this.query = ''});

  @override
  Widget build(BuildContext context) {
    final c = GoTechColors.of(context);
    return Row(children: [
      Expanded(
        child: Container(
          height: kGoTechToolbarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(kGoTechToolbarRadius),
              border: Border.all(color: c.line)),
          child: Row(children: [
            Icon(Icons.search_rounded, size: 16, color: c.muted),
            const SizedBox(width: 8),
            Text(
                query.isEmpty
                    ? 'Kişi, firma, bilgisayar adı ya da ID ara'
                    : query,
                style: TextStyle(
                    fontSize: kGoTechFontBody,
                    color: query.isEmpty ? c.faint : c.fg)),
          ]),
        ),
      ),
      const SizedBox(width: kGoTechToolbarGap),
      Icon(Icons.check_box_outline_blank, size: 18, color: c.muted),
      const SizedBox(width: 6),
      Text('Sadece çevrimiçi',
          style: TextStyle(fontSize: kGoTechFontBody, color: c.muted)),
      const SizedBox(width: 12),
      Icon(Icons.sort_rounded, size: 18, color: c.fg),
      const SizedBox(width: 6),
      const GoTechMoreButton(onTap: null),
    ]);
  }
}
