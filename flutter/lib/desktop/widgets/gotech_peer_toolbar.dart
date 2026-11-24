import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/peer_tab_page.dart';
import 'package:flutter_hbb/common/widgets/peers_view.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/peer_tab_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

import 'gotech_rehber.dart';
import 'gotech_view_parts.dart';
import 'gotech_tokens.dart';

// The bar above the GoTech peer table: search, "Sadece çevrimiçi", sorting and a "⋯" with refresh.

const _kSearchHint = 'Kişi, firma, bilgisayar adı ya da ID ara';
const _kSearchIconSize = 16.0;
const _kSearchContentPadding =
    EdgeInsets.symmetric(horizontal: 10, vertical: 9);

Peers _peersOf(int tab) {
  if (tab == PeerTabIndex.recent.index) return gFFI.recentPeersModel;
  if (tab == PeerTabIndex.fav.index) return gFFI.favoritePeersModel;
  if (tab == PeerTabIndex.lan.index) return gFFI.lanPeersModel;
  return gFFI.abModel.peersModel;
}

class _SearchField extends StatefulWidget {
  const _SearchField();

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _focusNode = FocusNode(debugLabel: 'GoTechPeerSearch');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _set(String text) {
    final wasSearching = peerSearchText.value.trim().isNotEmpty;
    peerSearchText.value = text;
    // a search looks in every company; picking one in the sidebar then narrows it
    if (!wasSearching && text.trim().isNotEmpty) goTechSelectCompany(null);
  }

  void _clear() {
    peerSearchTextController.clear();
    _set('');
  }

  @override
  Widget build(BuildContext context) {
    final c = GoTechColors.of(context);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(kGoTechToolbarRadius),
          borderSide: BorderSide(color: color),
        );
    return SizedBox(
      height: kGoTechToolbarHeight,
      child: TextField(
        controller: peerSearchTextController,
        focusNode: _focusNode,
        onChanged: _set,
        maxLines: 1,
        style: const TextStyle(fontSize: kGoTechFontBody),
        cursorColor: c.fg,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: c.surface,
          hintText: _kSearchHint,
          hintStyle: TextStyle(fontSize: kGoTechFontBody, color: c.faint),
          contentPadding: _kSearchContentPadding,
          prefixIcon: Icon(Icons.search_rounded,
              size: _kSearchIconSize, color: c.muted),
          prefixIconConstraints:
              const BoxConstraints(minWidth: kGoTechToolbarHeight),
          suffixIcon: Obx(() => peerSearchText.value.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Aramayı temizle',
                  splashRadius: _kSearchIconSize,
                  icon: Icon(Icons.close_rounded,
                      size: _kSearchIconSize, color: c.muted),
                  onPressed: _clear,
                )),
          border: border(c.line),
          enabledBorder: border(c.line),
          focusedBorder: border(kGoTechFocus),
        ),
      ).workaroundFreezeLinuxMint(),
    );
  }
}

class _OnlineOnlyBox extends StatelessWidget {
  final int tab;
  const _OnlineOnlyBox({required this.tab});

  void _toggle(bool on) {
    peerOnlineOnly.value = on;
    // the lists only ask about the rows on screen; get every peer's state once before hiding the offline ones
    final ids = _peersOf(tab).peers.map((p) => p.id).toList();
    if (on && ids.isNotEmpty) bind.queryOnlines(ids: ids);
  }

  @override
  Widget build(BuildContext context) {
    final c = GoTechColors.of(context);
    return Obx(() => InkWell(
          borderRadius: BorderRadius.circular(kGoTechToolbarRadius),
          onTap: () => _toggle(!peerOnlineOnly.value),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Checkbox(
              value: peerOnlineOnly.value,
              onChanged: (v) => _toggle(v == true),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              activeColor: c.fg,
              checkColor: c.background,
              side: BorderSide(color: c.muted),
            ),
            Text('Sadece çevrimiçi',
                style: TextStyle(fontSize: kGoTechFontBody, color: c.muted)),
          ]).paddingOnly(right: kGoTechSmallDotSize),
        ));
  }
}

class GoTechPeerToolbar extends StatelessWidget {
  final int tab;
  final VoidCallback onRefresh;
  const GoTechPeerToolbar(
      {Key? key, required this.tab, required this.onRefresh})
      : super(key: key);

  void _menu(BuildContext context, Offset p) {
    showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(p.dx, p.dy, p.dx, p.dy),
      items: [
        PopupMenuItem(
          onTap: onRefresh,
          child: const ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.refresh_rounded),
            title: Text('Listeyi yenile'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Expanded(child: _SearchField()),
      const SizedBox(width: kGoTechToolbarGap),
      _OnlineOnlyBox(tab: tab),
      if (tab != PeerTabIndex.recent.index) const PeerSortDropdown(),
      GoTechMoreButton(
          onTap: (p) => _menu(context, p), tooltip: 'Liste menüsü'),
    ]);
  }
}
