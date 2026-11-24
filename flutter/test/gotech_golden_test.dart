import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/desktop/widgets/gotech_connect_view.dart';
import 'package:flutter_hbb/desktop/widgets/gotech_peer_format.dart';
import 'package:flutter_hbb/desktop/widgets/gotech_sidebar_footer_view.dart';
import 'package:flutter_hbb/desktop/widgets/gotech_sidebar_view.dart';
import 'package:flutter_hbb/desktop/widgets/gotech_table_view.dart';
import 'package:flutter_hbb/desktop/widgets/gotech_tokens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'gotech_fixtures.dart';

// Renders the GoTech main window from plain data and writes PNGs to test/goldens/ (not committed), so the
// layout can be looked at without building the app. The real sidebar, rows and dropdown views are used;
// only the connect row and the toolbar are stand-ins, since those need the native bridge.

const _kWindow = Size(1100, 720);
const _kDropWidth = 610.0;
final _shotKey = GlobalKey();

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<void> family(String name, List<String> paths) async {
    final files = paths.map(File.new).where((f) => f.existsSync()).toList();
    if (files.isEmpty) return;
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
    }
    await loader.load();
  }

  await family('Roboto', [
    '$dir/Roboto-Regular.ttf',
    '$dir/Roboto-Medium.ttf',
    '$dir/Roboto-Bold.ttf',
  ]);
  await family('MaterialIcons', ['$dir/MaterialIcons-Regular.otf']);
  // arrows such as ↵ are not in Roboto
  await family(
      'Fallback', ['/System/Library/Fonts/Supplemental/Arial Unicode.ttf']);
}

ThemeData _theme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  // the colors GoTechColors reads from MyTheme.darkTheme / lightTheme
  return ThemeData(
    brightness: brightness,
    useMaterial3: false,
    fontFamily: 'Roboto',
    fontFamilyFallback: const ['Fallback'],
    scaffoldBackgroundColor: dark ? const Color(0xFF18191E) : Colors.white,
    cardColor: dark ? const Color(0xFF24252B) : const Color(0xFFEFEFF2),
    hoverColor: dark
        ? const Color.fromARGB(255, 45, 46, 53)
        : const Color.fromARGB(255, 224, 224, 224),
  );
}

const _kNav = [
  (Icons.schedule_rounded, 'Son oturumlar'),
  (Icons.star_border_rounded, 'Favoriler'),
  (Icons.wifi_rounded, 'Yerel ağ'),
  (Icons.contacts_outlined, 'Rehber'),
];

Widget _sidebar(Widget logo, {String? selected, String query = ''}) {
  void none() {}
  return GoTechSidebarView(
    header: Row(children: [
      Expanded(
        child: SizedBox(
          height: kGoTechLogoHeight,
          child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              child: logo),
        ),
      ),
      GoTechIconButton(
          icon: Icons.settings_outlined, tooltip: 'Ayarlar', onTap: none),
    ]),
    nav: [
      for (final (icon, label) in _kNav)
        GoTechNavItem(
            icon: icon, label: label, selected: label == 'Rehber', onTap: none),
    ],
    companies: GoTechCompanyList(
      allCount:
          kFixturePeers.where((p) => p.matches(GoTechQuery(query))).length,
      companies: fixtureCompanies(query),
      selected: selected,
      onSelect: (_) {},
    ),
    companiesAfter: _kNav.length - 1,
    footer: [
      GoTechCompactIdRows(
        id: TextEditingController(text: '318 402 776'),
        password: TextEditingController(text: 'k4m9tq'),
        idActions: [
          GoTechIconButton(
              icon: Icons.copy_rounded,
              tooltip: '',
              onTap: none,
              compact: true),
        ],
        passwordActions: [
          for (final icon in [
            Icons.copy_rounded,
            Icons.refresh_rounded,
            Icons.edit_outlined,
          ])
            GoTechIconButton(
                icon: icon, tooltip: '', onTap: none, compact: true),
        ],
      ),
      const GoTechStatusView(
          color: kGoTechOnline, text: 'Hazır, ekip bilgisayarı'),
      const GoTechAccountRowView(name: 'Ahmet Yılmaz'),
    ],
  );
}

int _byOnlineThenName(GoTechPeerInfo a, GoTechPeerInfo b) {
  if (a.online != b.online) return a.online ? -1 : 1;
  return goTechNormalize(goTechPeerTitle(a))
      .compareTo(goTechNormalize(goTechPeerTitle(b)));
}

Widget _main(
    {String? selected,
    String query = '',
    String? selectedId,
    String connectText = '17 575 412',
    Widget? dropdown}) {
  bool inScope(GoTechPeerInfo p) => selected == null || p.company == selected;
  final all = kFixturePeers.where(inScope).toList();
  final rows = all.where((p) => p.matches(GoTechQuery(query))).toList()
    ..sort(_byOnlineThenName);
  final online = all.where((p) => p.online).length;
  final showCompany = selected == null || query.isNotEmpty;
  final box = GoTechTableBox(
    title: GoTechBoxTitle(
      title: selected ?? 'Tüm bilgisayarlar',
      subtitle: '${all.length} bilgisayar, $online çevrimiçi'
          '${query.isEmpty ? '' : '. Aramaya uyan: ${rows.length}'}',
      onMore: (_) {},
    ),
    rows: ListView(children: [
      for (final p in rows)
        GoTechPeerRowView(
          data: fixtureRow(p, showCompany: showCompany),
          selected: p.id == selectedId,
          hovered: p.id == selectedId,
          onConnect: () {},
          onMore: (_) {},
        ),
    ]),
  );
  final column = Padding(
    padding: kGoTechMainPadding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: kGoTechBannerGap),
        FakeConnectRow(text: connectText, focused: dropdown != null),
        const SizedBox(height: kGoTechConnectGap),
        FakeToolbar(query: query),
        const SizedBox(height: kGoTechToolbarGap),
        Expanded(child: box.marginOnly(bottom: kGoTechBoxBottom)),
      ],
    ),
  );
  if (dropdown == null) return column;
  return Stack(children: [
    column,
    Positioned(
        left: kGoTechMainPadding.left,
        top: kGoTechMainPadding.top + kGoTechBannerGap + 48,
        child: dropdown),
  ]);
}

Widget _drop(String query) => GoTechConnectDropView(
      items: goTechConnectItems(GoTechQuery(query),
          peers: kFixturePeers, companies: fixtureCompanyCounts()),
      highlighted: 0,
      onPick: (_) {},
      companyColor: companyColor,
      width: _kDropWidth,
    );

Future<void> _shoot(WidgetTester tester, String name,
    {required Widget Function(Widget logo) main,
    String? selected,
    String query = '',
    Brightness brightness = Brightness.dark}) async {
  final logoFile = File(brightness == Brightness.dark
      ? 'assets/logo_dark.png'
      : 'assets/logo_light.png');
  final Uint8List bytes = logoFile.readAsBytesSync();
  final logo = Image.memory(bytes, fit: BoxFit.contain);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _theme(brightness),
    home: Scaffold(
      body: RepaintBoundary(
        key: _shotKey,
        // the app paints this behind the home page; the boundary would leave it transparent
        child: ColoredBox(
          color: _theme(brightness).scaffoldBackgroundColor,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sidebar(logo, selected: selected, query: query),
              Expanded(child: main(logo)),
            ],
          ),
        ),
      ),
    ),
  ));
  await tester.runAsync(() =>
      precacheImage(MemoryImage(bytes), tester.element(find.byType(Scaffold))));
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(_shotKey));
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('test/goldens/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_loadFonts);

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = _kWindow;
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('rehber: one company selected', (tester) async {
    await _shoot(tester, 'gotech_rehber_company',
        selected: kKuzey,
        main: (_) => _main(selected: kKuzey, selectedId: '623020116'));
  });

  testWidgets('rehber: all computers', (tester) async {
    await _shoot(tester, 'gotech_rehber_all', main: (_) => _main());
  });

  testWidgets('rehber: search across companies', (tester) async {
    await _shoot(tester, 'gotech_rehber_search',
        query: 'de', main: (_) => _main(query: 'de'));
  });

  testWidgets('rehber: light theme', (tester) async {
    await _shoot(tester, 'gotech_rehber_light',
        selected: kKuzey,
        brightness: Brightness.light,
        main: (_) => _main(selected: kKuzey, selectedId: '623020116'));
  });

  testWidgets('connect field: "dil"', (tester) async {
    await _shoot(tester, 'gotech_connect_dil',
        selected: kKuzey,
        main: (_) => _main(
            selected: kKuzey, connectText: 'dil', dropdown: _drop('dil')));
  });

  testWidgets('connect field: "2298"', (tester) async {
    await _shoot(tester, 'gotech_connect_2298',
        selected: kKuzey,
        main: (_) => _main(
            selected: kKuzey, connectText: '2 298', dropdown: _drop('2298')));
  });
}
