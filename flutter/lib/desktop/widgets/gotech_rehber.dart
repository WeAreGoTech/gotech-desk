import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/peers_view.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/ab_model.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/peer_tab_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

import 'gotech_peer_row.dart';
import 'gotech_sidebar_view.dart';
import 'gotech_table_view.dart';

// The GoTech address book ("Rehber"): companies are the address book tags, one selected at a time.

const kGoTechNoCompany = 'Firması yok';
const kGoTechAllComputers = 'Tüm bilgisayarlar';

/// Switches the peer tab like a click on the old tab strip, which the GoTech layout no longer has.
Future<void> goTechSelectPeerTab(int tab) async {
  final model = gFFI.peerTabModel;
  if (tab != model.currentTab) model.setCurrentTabCachedPeers([]);
  model.setCurrentTab(tab);
  if (tab == PeerTabIndex.ab.index) {
    gFFI.abModel.pullAb(force: null, quiet: false);
  }
  await bind.setLocalFlutterOption(k: kOptionPeerTabIndex, v: tab.toString());
}

/// The selected company tag, or null for all computers.
String? goTechSelectedCompany() {
  final tags = gFFI.abModel.selectedTags;
  return tags.isEmpty ? null : tags.first;
}

void goTechSelectCompany(String? tag) {
  final tags = gFFI.abModel.selectedTags;
  if (tag == null) {
    tags.clear();
  } else {
    tags
      ..clear()
      ..add(tag);
  }
}

/// Opens the address book on one company, from the connect field's dropdown.
Future<void> goTechOpenCompany(String tag) async {
  goTechSelectCompany(tag);
  await goTechSelectPeerTab(PeerTabIndex.ab.index);
}

String goTechCompanyTitle(String? tag) => tag == null
    ? kGoTechAllComputers
    : tag == kUntagged
        ? kGoTechNoCompany
        : tag;

bool _inCompany(Peer p, String? tag) {
  if (tag == null) return true;
  if (tag == kUntagged) return p.tags.isEmpty;
  return p.tags.contains(tag);
}

/// Passes the toolbar search and the "Sadece çevrimiçi" box.
bool goTechPassesFilters(Peer p) =>
    (!peerOnlineOnly.value || p.online) &&
    goTechPeerMatches(peerSearchText.value, p);

List<String> goTechAbTags() {
  final tags = gFFI.abModel.currentAbTags.toList();
  if (gFFI.abModel.sortTags.value) tags.sort();
  return tags;
}

/// Every company with its number of computers, for the connect field's dropdown.
Map<String, int> goTechCompanyCounts() {
  final peers = gFFI.abModel.currentAbPeers;
  return {
    for (final t in goTechAbTags())
      t: peers.where((p) => p.tags.contains(t)).length,
  };
}

/// The companies in the sidebar. While searching, the counts are matches and empty companies dim.
List<GoTechCompanyData> goTechCompanyList() {
  final peers = gFFI.abModel.currentAbPeers;
  final searching = peerSearchText.value.trim().isNotEmpty;
  GoTechCompanyData item(String tag, String name, Color? color) {
    final n =
        peers.where((p) => _inCompany(p, tag) && goTechPassesFilters(p)).length;
    return GoTechCompanyData(
        tag: tag, name: name, color: color, count: n, dim: searching && n == 0);
  }

  return [
    for (final t in goTechAbTags())
      item(t, t, gFFI.abModel.getCurrentAbTagColor(t)),
    if (peers.any((p) => p.tags.isEmpty))
      item(kUntagged, kGoTechNoCompany, null),
  ];
}

int goTechVisiblePeerCount() =>
    gFFI.abModel.currentAbPeers.where(goTechPassesFilters).length;

/// The address book box: the selected company, its counts and the rows.
class GoTechAbBox extends StatelessWidget {
  final Widget rows;
  final void Function(Offset globalPosition)? onMore;
  const GoTechAbBox({Key? key, required this.rows, this.onMore})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final title = ListenableBuilder(
      // online states change on the peers model, not on the address book lists
      listenable: gFFI.abModel.peersModel,
      builder: (context, _) => Obx(() {
        final tag = goTechSelectedCompany();
        final scope = gFFI.abModel.currentAbPeers
            .where((p) => _inCompany(p, tag))
            .toList();
        final online = scope.where((p) => p.online).length;
        var subtitle = '${scope.length} bilgisayar, $online çevrimiçi';
        if (peerSearchText.value.trim().isNotEmpty) {
          subtitle +=
              '. Aramaya uyan: ${scope.where(goTechPassesFilters).length}';
        }
        return GoTechBoxTitle(
            title: goTechCompanyTitle(tag), subtitle: subtitle, onMore: onMore);
      }),
    );
    return GoTechTableBox(title: title, rows: rows);
  }
}
