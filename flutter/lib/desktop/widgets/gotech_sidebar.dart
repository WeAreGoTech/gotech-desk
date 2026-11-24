import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';
import 'package:flutter_hbb/models/peer_tab_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'gotech_account_menu.dart';
import 'gotech_api.dart';
import 'gotech_home.dart';
import 'gotech_rehber.dart';
import 'gotech_sidebar_footer_view.dart';
import 'gotech_sidebar_view.dart';

// The left column of the GoTech main window: logo, the peer tabs with the companies under Rehber, and at
// the foot this computer's ID and password, the service status and the account.

const _kTabLabels = [
  'Son oturumlar',
  'Favoriler',
  'Yerel ağ',
  'Rehber',
  'Erişilebilir cihazlar',
];
const _kTabIcons = [
  Icons.schedule_rounded,
  Icons.star_border_rounded,
  Icons.wifi_rounded,
  Icons.contacts_outlined,
  Icons.devices_other_rounded,
];
const _kStatusPollInterval = Duration(seconds: 1);

class GoTechSidebar extends StatelessWidget {
  /// This computer's ID, password and service status; off when the app only connects out.
  final bool showDevice;
  const GoTechSidebar({Key? key, required this.showDevice}) : super(key: key);

  Widget _header(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: SizedBox(
                height: kGoTechLogoHeight,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  child: loadLogo(),
                ),
              ),
            ),
            // the settings gear used to sit on the big ID card
            GoTechIconButton(
              icon: Icons.settings_outlined,
              tooltip: translate('Settings'),
              onTap: DesktopTabPage.onAddSetting,
            ),
          ]),
          loadPowered(context),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Consumer<PeerTabModel>(builder: (context, model, _) {
      final tabs = model.visibleEnabledOrderedIndexs;
      final abAt = tabs.indexOf(PeerTabIndex.ab.index);
      final showCompanies =
          abAt >= 0 && model.currentTab == PeerTabIndex.ab.index;
      return GoTechSidebarView(
        header: _header(context),
        nav: [
          for (final t in tabs)
            GoTechNavItem(
              icon: _kTabIcons[t],
              label: _kTabLabels[t],
              selected: model.currentTab == t,
              onTap:
                  goTechCanSelectTab(t) ? () => goTechSelectPeerTab(t) : null,
            ),
        ],
        companies: showCompanies ? const _Companies() : null,
        companiesAfter: abAt,
        footer: [
          if (showDevice) const GoTechDeviceCard(compact: true),
          if (showDevice) const GoTechStatusLine(),
          ClipRRect(
            borderRadius: BorderRadius.circular(kGoTechAccountRadius),
            child: const GoTechAccountButton(expanded: true),
          ),
        ],
      );
    });
  }
}

class _Companies extends StatelessWidget {
  const _Companies();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      // online states change on the peers model, not on the address book lists
      listenable: gFFI.abModel.peersModel,
      builder: (context, _) => Obx(() {
        if (!gFFI.userModel.isLogin) return const SizedBox.shrink();
        final tally = goTechCompanyTally();
        return GoTechCompanyList(
          allCount: tally.all,
          companies: tally.companies,
          selected: goTechSelectedCompany(),
          onSelect: goTechSelectCompany,
        );
      }),
    );
  }
}

/// "Hazır, ekip bilgisayarı" or what is wrong, with "Başlat" when the service is stopped. It polls the
/// connection state that the old status bar under the list used to poll.
class GoTechStatusLine extends StatefulWidget {
  const GoTechStatusLine({Key? key}) : super(key: key);

  @override
  State<GoTechStatusLine> createState() => _GoTechStatusLineState();
}

class _GoTechStatusLineState extends State<GoTechStatusLine> {
  final _svcStopped = Get.find<RxBool>(tag: 'stop-service');
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = periodic_immediate(_kStatusPollInterval, pollConnectStatus);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (_svcStopped.value) {
        return GoTechStatusView(
          color: kColorWarn,
          text: 'Servis çalışmıyor',
          actionLabel: 'Başlat',
          onAction: () => start_service(true),
        );
      }
      switch (stateGlobal.svcStatus.value) {
        case SvcStatus.ready:
          return GoTechStatusView(
            color: kGoTechOnline,
            text: GoTechRegistration.isTeamMachine
                ? 'Hazır, ekip bilgisayarı'
                : 'Hazır',
          );
        case SvcStatus.connecting:
          return const GoTechStatusView(
              color: kColorWarn, text: 'Sunucuya bağlanılıyor');
        default:
          return const GoTechStatusView(
              color: kGoTechStatusError,
              text: 'Hazır değil, bağlantını kontrol et');
      }
    });
  }
}
