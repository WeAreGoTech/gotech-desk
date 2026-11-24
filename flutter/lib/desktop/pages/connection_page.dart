// main window right pane

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/widgets/connection_page_title.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/widgets/popup_menu.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_hbb/models/peer_model.dart';

import '../../common.dart';
import '../../common/formatter/id_formatter.dart';
import '../../common/widgets/peer_tab_page.dart';
import '../../common/widgets/autocomplete.dart';
import '../../models/platform_model.dart';
import '../../desktop/widgets/material_mod_popup_menu.dart' as mod_menu;
import '../../desktop/widgets/gotech_connect_view.dart';
import '../../desktop/widgets/gotech_peer_format.dart';
import '../../desktop/widgets/gotech_peer_row.dart';
import '../../desktop/widgets/gotech_rehber.dart';

/// Reads the rendezvous connection state into [stateGlobal]. The status bar below and the GoTech sidebar
/// poll it.
Future<void> pollConnectStatus() async {
  final status =
      jsonDecode(await bind.mainGetConnectStatus()) as Map<String, dynamic>;
  final statusNum = status['status_num'] as int;
  if (statusNum == 0) {
    stateGlobal.svcStatus.value = SvcStatus.connecting;
  } else if (statusNum == -1) {
    stateGlobal.svcStatus.value = SvcStatus.notReady;
  } else if (statusNum == 1) {
    stateGlobal.svcStatus.value = SvcStatus.ready;
  } else {
    stateGlobal.svcStatus.value = SvcStatus.notReady;
  }
  try {
    stateGlobal.videoConnCount.value = status['video_conn_count'] as int;
  } catch (_) {}
}

class OnlineStatusWidget extends StatefulWidget {
  const OnlineStatusWidget({Key? key, this.onSvcStatusChanged})
      : super(key: key);

  final VoidCallback? onSvcStatusChanged;

  @override
  State<OnlineStatusWidget> createState() => _OnlineStatusWidgetState();
}

/// State for the connection page.
class _OnlineStatusWidgetState extends State<OnlineStatusWidget> {
  final _svcStopped = Get.find<RxBool>(tag: 'stop-service');
  final _svcIsUsingPublicServer = true.obs;
  Timer? _updateTimer;

  double get em => 14.0;
  double? get height => bind.isIncomingOnly() ? null : em * 3;

  void onUsePublicServerGuide() {
    const url = "https://rustdesk.com/pricing";
    canLaunchUrlString(url).then((can) {
      if (can) {
        launchUrlString(url);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _updateTimer = periodic_immediate(Duration(seconds: 1), () async {
      updateStatus();
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIncomingOnly = bind.isIncomingOnly();
    startServiceWidget() => Offstage(
          offstage: !_svcStopped.value,
          child: InkWell(
                  onTap: () async {
                    await start_service(true);
                  },
                  child: Text(translate("Start service"),
                      style: TextStyle(
                          decoration: TextDecoration.underline, fontSize: em)))
              .marginOnly(left: em),
        );

    setupServerWidget() => Flexible(
          child: Offstage(
            offstage: !(!_svcStopped.value &&
                stateGlobal.svcStatus.value == SvcStatus.ready &&
                _svcIsUsingPublicServer.value),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(', ', style: TextStyle(fontSize: em)),
                Flexible(
                  child: InkWell(
                    onTap: onUsePublicServerGuide,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            translate('setup_server_tip'),
                            style: TextStyle(
                                decoration: TextDecoration.underline,
                                fontSize: em),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        );

    basicWidget() => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: 8,
              width: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: _svcStopped.value ||
                        stateGlobal.svcStatus.value == SvcStatus.connecting
                    ? kColorWarn
                    : (stateGlobal.svcStatus.value == SvcStatus.ready
                        ? Color.fromARGB(255, 50, 190, 166)
                        : Color.fromARGB(255, 224, 79, 95)),
              ),
            ).marginSymmetric(horizontal: em),
            Container(
              width: isIncomingOnly ? 226 : null,
              child: _buildConnStatusMsg(),
            ),
            // stop
            if (!isIncomingOnly) startServiceWidget(),
            // ready && public
            // No need to show the guide if is custom client.
            if (!isIncomingOnly) setupServerWidget(),
          ],
        );

    return Container(
      height: height,
      child: Obx(() => isIncomingOnly
          ? Column(
              children: [
                basicWidget(),
                Align(
                        child: startServiceWidget(),
                        alignment: Alignment.centerLeft)
                    .marginOnly(top: 2.0, left: 22.0),
              ],
            )
          : basicWidget()),
    ).paddingOnly(right: isIncomingOnly ? 8 : 0);
  }

  _buildConnStatusMsg() {
    widget.onSvcStatusChanged?.call();
    return Text(
      _svcStopped.value
          ? translate("Service is not running")
          : stateGlobal.svcStatus.value == SvcStatus.connecting
              ? translate("connecting_status")
              : stateGlobal.svcStatus.value == SvcStatus.notReady
                  ? translate("not_ready_status")
                  : translate('Ready'),
      style: TextStyle(fontSize: em),
    );
  }

  updateStatus() async {
    await pollConnectStatus();
    _svcIsUsingPublicServer.value = await bind.mainIsUsingPublicServer();
  }
}

/// Connection page for connecting to a remote peer.
class ConnectionPage extends StatefulWidget {
  const ConnectionPage({Key? key, this.header}) : super(key: key);

  /// Shown above the connect bar in the GoTech layout.
  final Widget? header;

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

/// State for the connection page.
class _ConnectionPageState extends State<ConnectionPage>
    with SingleTickerProviderStateMixin, WindowListener {
  /// Controller for the id input bar.
  final _idController = IDTextEditingController();

  final RxBool _idInputFocused = false.obs;
  final FocusNode _idFocusNode = FocusNode();
  final TextEditingController _idEditingController = TextEditingController();

  String selectedConnectionType = 'Connect';

  bool isWindowMinimized = false;

  final AllPeersLoader _allPeersLoader =
      AllPeersLoader(includeFavorites: bind.isCustomClient());

  // GoTech connect field search
  final _goTechFieldKey = GlobalKey();
  VoidCallback? _goTechSubmitField;
  bool _goTechPicked = false;

  // https://github.com/flutter/flutter/issues/157244
  Iterable<Peer> _autocompleteOpts = [];

  final _menuOpen = false.obs;

  @override
  void initState() {
    super.initState();
    _allPeersLoader.init(setState);
    _idFocusNode.addListener(onFocusChanged);
    if (_idController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final lastRemoteId = await bind.mainGetLastRemoteId();
        if (lastRemoteId != _idController.id) {
          setState(() {
            _idController.id = lastRemoteId;
          });
        }
      });
    }
    Get.put<TextEditingController>(_idEditingController);
    Get.put<IDTextEditingController>(_idController);
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    _idController.dispose();
    windowManager.removeListener(this);
    _allPeersLoader.clear();
    _idFocusNode.removeListener(onFocusChanged);
    _idFocusNode.dispose();
    _idEditingController.dispose();
    if (Get.isRegistered<IDTextEditingController>()) {
      Get.delete<IDTextEditingController>();
    }
    if (Get.isRegistered<TextEditingController>()) {
      Get.delete<TextEditingController>();
    }
    super.dispose();
  }

  @override
  void onWindowEvent(String eventName) {
    super.onWindowEvent(eventName);
    if (eventName == 'minimize') {
      isWindowMinimized = true;
    } else if (eventName == 'maximize' || eventName == 'restore') {
      if (isWindowMinimized && isWindows) {
        // windows can't update when minimized.
        Get.forceAppUpdate();
      }
      isWindowMinimized = false;
    }
  }

  @override
  void onWindowEnterFullScreen() {
    // Remove edge border by setting the value to zero.
    stateGlobal.resizeEdgeSize.value = 0;
  }

  @override
  void onWindowLeaveFullScreen() {
    // Restore edge border to default edge size.
    stateGlobal.resizeEdgeSize.value = stateGlobal.isMaximized.isTrue
        ? kMaximizeEdgeSize
        : windowResizeEdgeSize;
  }

  @override
  void onWindowClose() {
    super.onWindowClose();
    bind.mainOnMainWindowClose();
  }

  void onFocusChanged() {
    _idInputFocused.value = _idFocusNode.hasFocus;
    if (_idFocusNode.hasFocus) {
      if (_allPeersLoader.needLoad) {
        _allPeersLoader.getAllPeers();
      }

      final textLength = _idEditingController.value.text.length;
      // Select all to facilitate removing text, just following the behavior of address input of chrome.
      _idEditingController.selection =
          TextSelection(baseOffset: 0, extentOffset: textLength);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOutgoingOnly = bind.isOutgoingOnly();
    if (bind.isCustomClient()) {
      return _buildGoTech(context);
    }
    return Column(
      children: [
        Expanded(
            child: Column(
          children: [
            Row(
              children: [
                Flexible(child: _buildRemoteIDTextField(context)),
              ],
            ).marginOnly(top: 22),
            SizedBox(height: 12),
            Divider().paddingOnly(right: 12),
            Expanded(child: PeerTabPage()),
          ],
        ).paddingOnly(left: 12.0)),
        if (!isOutgoingOnly) const Divider(height: 1),
        if (!isOutgoingOnly) OnlineStatusWidget()
      ],
    );
  }

  /// Callback for the connect button.
  /// Connects to the selected peer.
  void onConnect(
      {bool isFileTransfer = false,
      bool isViewCamera = false,
      bool isTerminal = false,
      bool isTcpTunneling = false}) {
    var id = _idController.id;
    connect(context, id,
        isFileTransfer: isFileTransfer,
        isViewCamera: isViewCamera,
        isTerminal: isTerminal,
        isTcpTunneling: isTcpTunneling);
  }

  /// UI for the remote ID TextField.
  /// Search for a peer.
  Widget _buildRemoteIDTextField(BuildContext context) {
    final goTech = bind.isCustomClient();
    final idField = goTech ? _buildGoTechIdField() : RawAutocomplete<Peer>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') {
                      _autocompleteOpts = const Iterable<Peer>.empty();
                    } else if (_allPeersLoader.peers.isEmpty &&
                        !_allPeersLoader.isPeersLoaded) {
                      Peer emptyPeer = Peer(
                        id: '',
                        username: '',
                        hostname: '',
                        alias: '',
                        platform: '',
                        tags: [],
                        hash: '',
                        password: '',
                        forceAlwaysRelay: false,
                        rdpPort: '',
                        rdpUsername: '',
                        loginName: '',
                        device_group_name: '',
                        note: '',
                      );
                      _autocompleteOpts = [emptyPeer];
                    } else {
                      String textWithoutSpaces =
                          textEditingValue.text.replaceAll(" ", "");
                      if (int.tryParse(textWithoutSpaces) != null) {
                        textEditingValue = TextEditingValue(
                          text: textWithoutSpaces,
                          selection: textEditingValue.selection,
                        );
                      }
                      String textToFind = textEditingValue.text.toLowerCase();
                      _autocompleteOpts = _allPeersLoader.peers
                          .where((peer) =>
                              peer.id.toLowerCase().contains(textToFind) ||
                              peer.username
                                  .toLowerCase()
                                  .contains(textToFind) ||
                              peer.hostname
                                  .toLowerCase()
                                  .contains(textToFind) ||
                              peer.alias.toLowerCase().contains(textToFind))
                          .toList();
                      _allPeersLoader.queryOnlines(_autocompleteOpts);
                    }
                    return _autocompleteOpts;
                  },
                  focusNode: _idFocusNode,
                  textEditingController: _idEditingController,
                  fieldViewBuilder: (
                    BuildContext context,
                    TextEditingController fieldTextEditingController,
                    FocusNode fieldFocusNode,
                    VoidCallback onFieldSubmitted,
                  ) =>
                      _idFieldView(context, fieldTextEditingController,
                          fieldFocusNode, onConnect),
                  onSelected: (option) {
                    setState(() {
                      _idController.id = option.id;
                      FocusScope.of(context).unfocus();
                    });
                  },
                  optionsViewBuilder: (BuildContext context,
                      AutocompleteOnSelected<Peer> onSelected,
                      Iterable<Peer> options) {
                    options = _autocompleteOpts;
                    double maxHeight = options.length * 50;
                    if (options.length == 1) {
                      maxHeight = 52;
                    } else if (options.length == 3) {
                      maxHeight = 146;
                    } else if (options.length == 4) {
                      maxHeight = 193;
                    }
                    maxHeight = maxHeight.clamp(0, 200);

                    return Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 5,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: Material(
                                elevation: 4,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: maxHeight,
                                    maxWidth: 319,
                                  ),
                                  child: _allPeersLoader.peers.isEmpty &&
                                          !_allPeersLoader.isPeersLoaded
                                      ? Container(
                                          height: 80,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ))
                                      : Padding(
                                          padding:
                                              const EdgeInsets.only(top: 5),
                                          child: ListView(
                                            children: options
                                                .map((peer) =>
                                                    AutocompletePeerTile(
                                                        onSelect: () =>
                                                            onSelected(peer),
                                                        peer: peer))
                                                .toList(),
                                          ),
                                        ),
                                ),
                              ))),
                    );
                  },
                );
    final connectButton = SizedBox(
      height: goTech ? 48.0 : 28.0,
      child: ElevatedButton(
        style: goTech
            ? ElevatedButton.styleFrom(
                backgroundColor: kGoTechRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)))
            : null,
        onPressed: () {
          goTech ? _goTechSubmit() : onConnect();
        },
        child: Text(translate("Connect"),
            style: goTech
                ? const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)
                : null),
      ),
    );
    final moreButton = Container(
                  height: goTech ? 48.0 : 28.0,
                  width: goTech ? 48.0 : 28.0,
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(goTech ? 12 : 8),
                  ),
                  child: Center(
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        var offset = Offset(0, 0);
                        return Obx(() => InkWell(
                              child: _menuOpen.value
                                  ? Transform.rotate(
                                      angle: pi,
                                      child: Icon(IconFont.more, size: 14),
                                    )
                                  : Icon(IconFont.more, size: 14),
                              onTapDown: (e) {
                                offset = e.globalPosition;
                              },
                              onTap: () async {
                                _menuOpen.value = true;
                                final x = offset.dx;
                                final y = offset.dy;
                                await mod_menu
                                    .showMenu(
                                  context: context,
                                  position: RelativeRect.fromLTRB(x, y, x, y),
                                  items: [
                                    (
                                      'Transfer file',
                                      () => onConnect(isFileTransfer: true)
                                    ),
                                    (
                                      'View camera',
                                      () => onConnect(isViewCamera: true)
                                    ),
                                    (
                                      '${translate('Terminal')} (beta)',
                                      () => onConnect(isTerminal: true)
                                    ),
                                    // `connect` routes this through the
                                    // desktop path only; the peer card gates
                                    // it the same way.
                                    if (isDesktop)
                                      (
                                        'TCP tunneling',
                                        () => onConnect(isTcpTunneling: true)
                                      ),
                                  ]
                                      .map((e) => MenuEntryButton<String>(
                                            childBuilder: (TextStyle? style) =>
                                                Text(
                                              translate(e.$1),
                                              style: style,
                                            ),
                                            proc: () => e.$2(),
                                            padding: EdgeInsets.symmetric(
                                                horizontal:
                                                    kDesktopMenuPadding.left),
                                            dismissOnClicked: true,
                                          ))
                                      .map((e) => e.build(
                                          context,
                                          const MenuConfig(
                                              commonColor: CustomPopupMenuTheme
                                                  .commonColor,
                                              height:
                                                  CustomPopupMenuTheme.height,
                                              dividerHeight:
                                                  CustomPopupMenuTheme
                                                      .dividerHeight)))
                                      .expand((i) => i)
                                      .toList(),
                                  elevation: 8,
                                )
                                    .then((_) {
                                  _menuOpen.value = false;
                                });
                              },
                            ));
                      },
                    ),
                  ),
                );
    if (goTech) {
      return Row(
        children: [
          Expanded(child: idField),
          const SizedBox(width: 10),
          connectButton,
          const SizedBox(width: 8),
          moreButton,
        ],
      );
    }
    var w = Container(
      width: 320 + 20 * 2,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(13)),
          border: Border.all(color: Theme.of(context).colorScheme.background)),
      child: Ink(
        child: Column(
          children: [
            getConnectionPageTitle(context, false).marginOnly(bottom: 15),
            Row(
              children: [
                Expanded(child: idField),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 13.0),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                connectButton,
                const SizedBox(width: 8),
                moreButton,
              ]),
            ),
          ],
        ),
      ),
    );
    return Container(
        constraints: const BoxConstraints(maxWidth: 600), child: w);
  }

  /// GoTech: the ID field also finds computers and companies. Upstream's RawAutocomplete with GoTech
  /// items: a direct connect for a typed ID, matching computers, matching companies.
  Widget _buildGoTechIdField() {
    return RawAutocomplete<GoTechConnectItem>(
      focusNode: _idFocusNode,
      textEditingController: _idEditingController,
      // a company opens the address book and leaves the field empty for the next search
      displayStringForOption: (item) =>
          item.kind == GoTechConnectKind.company ? '' : formatID(item.id),
      optionsBuilder: (value) {
        final query = GoTechQuery(value.text);
        if (query.isEmpty) return const [];
        final items = goTechConnectItems(query,
            peers: _goTechHits(query), companies: goTechCompanyCounts());
        final ids = items.map((e) => e.id).toSet();
        _allPeersLoader
            .queryOnlines(_allPeersLoader.peers.where((p) => ids.contains(p.id)));
        return items;
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        _goTechSubmitField = onFieldSubmitted;
        return KeyedSubtree(
          key: _goTechFieldKey,
          child: _idFieldView(context, controller, focusNode, _goTechSubmit),
        );
      },
      onSelected: _goTechRun,
      optionsViewBuilder: (context, onSelected, options) {
        final field =
            _goTechFieldKey.currentContext?.findRenderObject() as RenderBox?;
        return Align(
          alignment: Alignment.topLeft,
          child: GoTechConnectDropView(
            items: options.map(_goTechFresh).toList(),
            highlighted: AutocompleteHighlightedOption.of(context),
            onPick: onSelected,
            companyColor: gFFI.abModel.getCurrentAbTagColor,
            width: field?.size.width ?? kGoTechDropMinWidth,
          ),
        );
      },
    );
  }

  /// The known computers matching [query] (the address book entry wins a shared ID), with the recent
  /// sessions marked for ranking. Peers keep their folded search text, so a keystroke only re-checks it.
  List<GoTechPeerInfo> _goTechHits(GoTechQuery query) {
    final recent = {
      ...gFFI.recentPeersModel.peers.map((p) => p.id),
      ...gFFI.recentPeersModel.restPeerIds,
    };
    return [
      for (final p in _allPeersLoader.peers)
        if (goTechPeerMatches(query, p))
          goTechPeerInfo(p, recent: recent.contains(p.id)),
    ];
  }

  /// The same item with the online state the loader learned since the list was built.
  GoTechConnectItem _goTechFresh(GoTechConnectItem item) {
    final old = item.peer;
    if (old == null) return item;
    final p = _allPeersLoader.peers.firstWhereOrNull((e) => e.id == old.id);
    return p == null
        ? item
        : GoTechConnectItem.peer(goTechPeerInfo(p, recent: old.recent));
  }

  /// Enter or "Bağlan": run the highlighted item, or connect to the typed ID when none is shown.
  void _goTechSubmit() {
    _goTechPicked = false;
    _goTechSubmitField?.call();
    if (_goTechPicked) return;
    _idFocusNode.unfocus();
    onConnect();
  }

  void _goTechRun(GoTechConnectItem item) {
    _goTechPicked = true;
    _idFocusNode.unfocus();
    if (item.kind == GoTechConnectKind.company) {
      setState(() => _idController.id = '');
      goTechOpenCompany(item.company);
      return;
    }
    setState(() => _idController.id = item.id);
    onConnect();
  }

  /// The remote ID text field. Upstream's autocomplete and the GoTech one both build it.
  Widget _idFieldView(BuildContext context, TextEditingController controller,
      FocusNode focusNode, VoidCallback onSubmitted) {
    final goTech = bind.isCustomClient();
    updateTextAndPreserveSelection(controller, _idController.text);
    return Obx(() => TextField(
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword,
          focusNode: focusNode,
          style: TextStyle(
            fontFamily: 'WorkSans',
            fontSize: goTech ? 20 : 22,
            height: goTech ? 1.2 : 1.4,
          ),
          maxLines: 1,
          cursorColor: Theme.of(context).textTheme.titleLarge?.color,
          decoration: goTech
              ? _goTechInputDecoration(context)
              : InputDecoration(
              filled: false,
              counterText: '',
              hintText: _idInputFocused.value
                  ? null
                  : translate('Enter Remote ID'),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 15, vertical: 13)),
          controller: controller,
          inputFormatters: [IDTextInputFormatter()],
          onChanged: (v) {
            _idController.id = v;
          },
          onSubmitted: (_) {
            onSubmitted();
          },
        ).workaroundFreezeLinuxMint());
  }

  InputDecoration _goTechInputDecoration(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide:
          BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.15)),
    );
    return InputDecoration(
      filled: true,
      fillColor: Theme.of(context).cardColor,
      counterText: '',
      // the field searches the known computers and companies too
      hintText: _idInputFocused.value ? null : 'ID, firma ya da kişi adı yaz',
      prefixIcon: const Icon(Icons.desktop_windows_outlined, size: 20),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: kGoTechRed, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  /// The main area right of the GoTech sidebar: banners, the connect row and the peer table. The
  /// connection status that used to sit in a bar at the bottom is in the sidebar now.
  Widget _buildGoTech(BuildContext context) {
    return Padding(
      padding: kGoTechMainPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.header != null) widget.header!,
          const SizedBox(height: kGoTechBannerGap),
          _buildRemoteIDTextField(context),
          const SizedBox(height: kGoTechConnectGap),
          const Expanded(child: PeerTabPage(goTechLayout: true)),
        ],
      ),
    );
  }
}
