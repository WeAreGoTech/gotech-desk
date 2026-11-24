import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/peers_view.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/ab_model.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/peer_tab_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

import 'gotech_peer_format.dart';
import 'gotech_peer_row.dart';
import 'gotech_sidebar_view.dart';
import 'gotech_table_view.dart';

// The GoTech address book ("Rehber"): companies are the address book tags, one selected at a time.

const kGoTechNoCompany = 'Firması yok';
const kGoTechAllComputers = 'Tüm bilgisayarlar';

/// The sidebar may switch to [tab]: it is shown and the tab is not fixed by an option.
bool goTechCanSelectTab(int tab) =>
    !isOptionFixed(kOptionPeerTabIndex) &&
    gFFI.peerTabModel.visibleEnabledOrderedIndexs.contains(tab);

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

bool _companyExists(String tag) =>
    tag == kUntagged || gFFI.abModel.currentAbTags.contains(tag);

/// The selected company tag, or null for all computers. A company that left the address book in a
/// refresh counts as all computers, and the selection is dropped after this frame.
String? goTechSelectedCompany() {
  final tags = gFFI.abModel.selectedTags;
  if (tags.isEmpty) return null;
  final tag = tags.first;
  if (_companyExists(tag)) return tag;
  WidgetsBinding.instance
      .addPostFrameCallback((_) => goTechSelectCompany(null));
  return null;
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

/// Opens the address book on one company, from the connect field's dropdown. Does nothing when the
/// company is gone or the address book tab can't be shown.
Future<void> goTechOpenCompany(String tag) async {
  if (!_companyExists(tag)) return;
  final ab = PeerTabIndex.ab.index;
  if (gFFI.peerTabModel.currentTab == ab) {
    goTechSelectCompany(tag);
  } else if (goTechCanSelectTab(ab)) {
    goTechSelectCompany(tag);
    await goTechSelectPeerTab(ab);
  }
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

/// The toolbar search, prepared once for a pass over the peers.
GoTechQuery goTechSearchQuery() => GoTechQuery(peerSearchText.value);

/// Passes the toolbar search and the "Sadece çevrimiçi" box.
bool goTechPassesFilters(Peer p, GoTechQuery query) =>
    (!peerOnlineOnly.value || p.online) && goTechPeerMatches(query, p);

List<String> goTechAbTags() {
  final tags = gFFI.abModel.currentAbTags.toList();
  if (gFFI.abModel.sortTags.value) tags.sort();
  return tags;
}

/// Every company with its number of computers, for the connect field's dropdown.
Map<String, int> goTechCompanyCounts() {
  final counts = {for (final t in goTechAbTags()) t: 0};
  for (final p in gFFI.abModel.currentAbPeers) {
    for (final t in p.tags) {
      final n = counts[t.toString()];
      if (n != null) counts[t.toString()] = n + 1;
    }
  }
  return counts;
}

/// The sidebar list in one pass over the address book: the computers passing the filters, in all and
/// per company. While searching, companies without a match dim.
({int all, List<GoTechCompanyData> companies}) goTechCompanyTally() {
  final query = goTechSearchQuery();
  final counts = <String, int>{};
  var all = 0;
  var untagged = 0;
  var anyUntagged = false;
  for (final p in gFFI.abModel.currentAbPeers) {
    if (p.tags.isEmpty) anyUntagged = true;
    if (!goTechPassesFilters(p, query)) continue;
    all++;
    if (p.tags.isEmpty) untagged++;
    for (final t in p.tags) {
      counts[t.toString()] = (counts[t.toString()] ?? 0) + 1;
    }
  }
  GoTechCompanyData item(String tag, String name, Color? color, int n) =>
      GoTechCompanyData(
          tag: tag,
          name: name,
          color: color,
          count: n,
          dim: !query.isEmpty && n == 0);
  return (
    all: all,
    companies: [
      for (final t in goTechAbTags())
        item(t, t, gFFI.abModel.getCurrentAbTagColor(t), counts[t] ?? 0),
      if (anyUntagged) item(kUntagged, kGoTechNoCompany, null, untagged),
    ],
  );
}

/// The address book box: the selected company, its counts and the rows.
class GoTechAbBox extends StatelessWidget {
  final Widget rows;
  final void Function(Offset globalPosition)? onMore;
  const GoTechAbBox({Key? key, required this.rows, this.onMore})
      : super(key: key);

  String _subtitle(String? tag) {
    final query = goTechSearchQuery();
    var total = 0;
    var online = 0;
    var hits = 0;
    for (final p in gFFI.abModel.currentAbPeers) {
      if (!_inCompany(p, tag)) continue;
      total++;
      if (p.online) online++;
      if (!query.isEmpty && goTechPassesFilters(p, query)) hits++;
    }
    final counts = '$total bilgisayar, $online çevrimiçi';
    return query.isEmpty ? counts : '$counts. Aramaya uyan: $hits';
  }

  @override
  Widget build(BuildContext context) {
    final title = ListenableBuilder(
      // online states change on the peers model, not on the address book lists
      listenable: gFFI.abModel.peersModel,
      builder: (context, _) => Obx(() {
        final tag = goTechSelectedCompany();
        return GoTechBoxTitle(
            title: goTechCompanyTitle(tag),
            subtitle: _subtitle(tag),
            onMore: onMore);
      }),
    );
    return GoTechTableBox(title: title, rows: rows);
  }
}
