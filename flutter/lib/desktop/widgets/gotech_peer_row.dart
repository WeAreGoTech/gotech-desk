import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/common/widgets/peers_view.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/peer_tab_model.dart';
import 'package:get/get.dart';

import 'gotech_peer_format.dart';
import 'gotech_table_view.dart';
import 'gotech_tokens.dart';
import 'gotech_view_parts.dart';

// A real peer in the GoTech table: maps the Peer model onto GoTechPeerRowView and handles hover,
// selection, keyboard and the "⋯" menu.

/// The row the user clicked last, across all tabs.
final goTechSelectedPeerId = ''.obs;

GoTechPeerInfo goTechPeerInfo(Peer p, {bool recent = false}) => GoTechPeerInfo(
      id: p.id,
      alias: p.alias,
      hostname: p.hostname,
      tags: p.tags.map((e) => e.toString()).toList(),
      platform: p.platform,
      online: p.online,
      recent: recent,
      lastSeen: p.lastSeen,
    );

/// The GoTech search rule on a [Peer]; the toolbar search and the connect field both use it.
bool goTechPeerMatches(String query, Peer p) =>
    goTechPeerInfo(p).matches(query);

Widget goTechPlatformIcon(BuildContext context, String platform) =>
    ColorFiltered(
      colorFilter:
          ColorFilter.mode(GoTechColors.of(context).faint, BlendMode.srcIn),
      child: getPlatformImage(platform, size: kGoTechPlatformIconSize),
    );

/// The relative "Son görülme" text, or "Çevrimiçi".
String goTechSeenText(Peer p) => p.online
    ? kGoTechOnlineText
    : goTechLastSeenText(p.lastSeen, now: DateTime.now());

Widget _empty(String title, [String hint = '']) => Align(
    alignment: Alignment.topCenter,
    child: GoTechEmptyView(title: title, hint: hint));

/// The tab has no peers at all.
Widget goTechEmptyTab(PeerTabIndex tab) {
  switch (tab) {
    case PeerTabIndex.recent:
      return _empty('Henüz bir bilgisayara bağlanmadın.');
    case PeerTabIndex.fav:
      return _empty('Favori bilgisayar yok.',
          'Bir bilgisayarın ⋯ menüsünden favorilere ekleyebilirsin.');
    case PeerTabIndex.lan:
      return _empty('Yerel ağda bilgisayar bulunamadı.');
    default:
      return _empty('Rehber boş.');
  }
}

/// The tab has peers, but the search, the online filter or the company hides them all.
Widget goTechNoMatch(PeerTabIndex tab) {
  final q = peerSearchText.value.trim();
  if (q.isNotEmpty) {
    return _empty('“$q” ile eşleşen bilgisayar yok.',
        'ID\'nin tamamını biliyorsan üstteki kutuya yazıp doğrudan bağlanabilirsin.');
  }
  if (peerOnlineOnly.value) return _empty('Şu an çevrimiçi bilgisayar yok.');
  if (tab == PeerTabIndex.ab) return _empty('Bu firmada bilgisayar yok.');
  return _empty('Liste boş.');
}

class _ConnectIntent extends Intent {
  const _ConnectIntent();
}

class GoTechPeerRow extends StatefulWidget {
  final Peer peer;
  final PeerTabIndex tab;
  final VoidCallback onConnect;
  final Future<void> Function(BuildContext context, RelativeRect position)
      onMenu;

  const GoTechPeerRow({
    Key? key,
    required this.peer,
    required this.tab,
    required this.onConnect,
    required this.onMenu,
  }) : super(key: key);

  @override
  State<GoTechPeerRow> createState() => _GoTechPeerRowState();
}

class _GoTechPeerRowState extends State<GoTechPeerRow> {
  final _focusNode = FocusNode(debugLabel: 'GoTechPeerRow');
  bool _hovered = false;
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _select() {
    goTechSelectedPeerId.value = widget.peer.id;
    _focusNode.requestFocus();
  }

  void _menu(Offset position) {
    _select();
    widget.onMenu(
        context,
        RelativeRect.fromLTRB(
            position.dx, position.dy, position.dx, position.dy));
  }

  /// The company goes in front of the hostname when the rows come from more than one company.
  bool get _showCompany {
    if (widget.tab != PeerTabIndex.ab) return true;
    return gFFI.abModel.selectedTags.isEmpty ||
        peerSearchText.value.trim().isNotEmpty;
  }

  GoTechRowData _data(BuildContext context) {
    final p = widget.peer;
    final info = goTechPeerInfo(p);
    final company = _showCompany ? info.company : '';
    return GoTechRowData(
      title: goTechPeerTitle(info),
      detail: goTechPeerDetail(info),
      company: company,
      companyColor:
          company.isEmpty ? null : gFFI.abModel.getCurrentAbTagColor(company),
      idText: formatID(p.id),
      seenText: goTechSeenText(p),
      online: p.online,
      platformIcon:
          p.platform.isEmpty ? null : goTechPlatformIcon(context, p.platform),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: _focusNode,
      mouseCursor: SystemMouseCursors.basic,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): _ConnectIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): _ConnectIntent(),
      },
      actions: {
        _ConnectIntent:
            CallbackAction<_ConnectIntent>(onInvoke: (_) => widget.onConnect()),
      },
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _select,
        onDoubleTap: widget.onConnect,
        onSecondaryTapUp: (d) => _menu(d.globalPosition),
        child: Obx(() => GoTechPeerRowView(
              data: _data(context),
              selected: goTechSelectedPeerId.value == widget.peer.id,
              hovered: _hovered,
              focused: _focused,
              onConnect: widget.onConnect,
              onMore: _menu,
            )),
      ),
    );
  }
}
