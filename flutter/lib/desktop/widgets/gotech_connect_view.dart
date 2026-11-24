import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:get/get.dart';

import 'gotech_peer_format.dart';
import 'gotech_view_parts.dart';
import 'gotech_tokens.dart';

// The dropdown under the connect field, drawn from plain data. connection_page.dart opens it through
// its RawAutocomplete and runs the picked item.

const _kTabular = [FontFeature.tabularFigures()];
const _kMonitorIconSize = 18.0;

class _KeyHint extends StatelessWidget {
  final String text;
  const _KeyHint(this.text);

  @override
  Widget build(BuildContext context) {
    final c = GoTechColors.of(context);
    return Container(
      padding: kGoTechKeyHintPadding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kGoTechKeyHintRadius),
        border: Border.all(color: c.faint),
      ),
      child:
          Text(text, style: TextStyle(fontSize: kGoTechFontKey, color: c.fg)),
    );
  }
}

class _DropItem extends StatelessWidget {
  final Widget lead;
  final String title;
  final Widget subtitle;
  final String trailing;
  final String hint;
  final bool active;
  final VoidCallback onTap;

  const _DropItem({
    Key? key,
    required this.lead,
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.active,
    required this.onTap,
    this.trailing = '',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = GoTechColors.of(context);
    return Material(
      color: active ? c.raised : Colors.transparent,
      borderRadius: BorderRadius.circular(kGoTechDropItemRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(kGoTechDropItemRadius),
        hoverColor: c.hover,
        onTap: onTap,
        child: Padding(
          padding: kGoTechDropItemPadding,
          child: Row(children: [
            SizedBox(
                width: kGoTechStatusColumnWidth, child: Center(child: lead)),
            const SizedBox(width: kGoTechColumnGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: kGoTechFontBody,
                          fontWeight: FontWeight.w600,
                          height: kGoTechLineHeight)),
                  const SizedBox(height: 2),
                  subtitle,
                ],
              ),
            ),
            if (trailing.isNotEmpty)
              Text(trailing,
                      style: const TextStyle(
                          fontSize: kGoTechFontId, fontFeatures: _kTabular))
                  .marginOnly(left: kGoTechColumnGap),
            if (active) _KeyHint(hint).marginOnly(left: kGoTechColumnGap),
          ]),
        ),
      ),
    );
  }
}

/// The open dropdown: sections, the highlighted item and the key hints at the bottom.
class GoTechConnectDropView extends StatefulWidget {
  final List<GoTechConnectItem> items;
  final int highlighted;
  final ValueChanged<GoTechConnectItem> onPick;
  final Color Function(String company) companyColor;
  final double width;

  const GoTechConnectDropView({
    Key? key,
    required this.items,
    required this.highlighted,
    required this.onPick,
    required this.companyColor,
    required this.width,
  }) : super(key: key);

  @override
  State<GoTechConnectDropView> createState() => _GoTechConnectDropViewState();
}

class _GoTechConnectDropViewState extends State<GoTechConnectDropView> {
  final _activeKey = GlobalKey();

  @override
  void didUpdateWidget(GoTechConnectDropView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlighted != widget.highlighted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _activeKey.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.5);
      });
    }
  }

  Widget _subtitle(BuildContext context, GoTechConnectItem item) {
    final c = GoTechColors.of(context);
    final style = TextStyle(
        fontSize: kGoTechFontSmall, color: c.muted, height: kGoTechLineHeight);
    switch (item.kind) {
      case GoTechConnectKind.direct:
        return Text('Rehberde olmasa da bağlanır', style: style);
      case GoTechConnectKind.company:
        return Text('${item.companyCount} bilgisayar', style: style);
      case GoTechConnectKind.peer:
        final p = item.peer!;
        return Text.rich(
          TextSpan(children: [
            if (p.company.isNotEmpty) ...[
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: GoTechColorDot(
                        color: widget.companyColor(p.company),
                        size: kGoTechSmallDotSize)
                    .marginOnly(right: kGoTechSmallDotSize - 1),
              ),
              TextSpan(text: '${p.company}, '),
            ],
            TextSpan(text: goTechPeerDetail(p)),
          ]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
    }
  }

  Widget _item(BuildContext context, int i) {
    final item = widget.items[i];
    final active = i == widget.highlighted;
    final c = GoTechColors.of(context);
    final Widget lead;
    final String title;
    switch (item.kind) {
      case GoTechConnectKind.direct:
        lead = Icon(Icons.desktop_windows_outlined,
            size: _kMonitorIconSize, color: c.muted);
        title = '${formatID(item.id)} kimliğine bağlan';
      case GoTechConnectKind.peer:
        lead = GoTechStatusDot(online: item.peer!.online);
        title = goTechPeerTitle(item.peer!);
      case GoTechConnectKind.company:
        lead = GoTechColorDot(color: widget.companyColor(item.company));
        title = item.company;
    }
    return _DropItem(
      key: active ? _activeKey : null,
      lead: lead,
      title: title,
      subtitle: _subtitle(context, item),
      trailing: item.kind == GoTechConnectKind.peer ? formatID(item.id) : '',
      hint: item.kind == GoTechConnectKind.company ? '↵ Aç' : '↵ Bağlan',
      active: active,
      onTap: () => widget.onPick(item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = GoTechColors.of(context);
    final section = TextStyle(fontSize: kGoTechFontTiny, color: c.faint);
    final children = <Widget>[];
    String last = '';
    for (var i = 0; i < widget.items.length; i++) {
      final kind = widget.items[i].kind;
      final name = kind == GoTechConnectKind.peer
          ? 'Bilgisayarlar'
          : kind == GoTechConnectKind.company
              ? 'Firmalar'
              : '';
      if (name.isNotEmpty && name != last) {
        children.add(Padding(
            padding: kGoTechDropSectionPadding,
            child: Text(name, style: section)));
      }
      last = name;
      children.add(_item(context, i));
    }
    return Container(
      width: widget.width,
      margin: const EdgeInsets.only(top: kGoTechDropGap),
      constraints: const BoxConstraints(maxHeight: kGoTechDropMaxHeight),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(kGoTechDropRadius),
        border: Border.all(color: c.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(kGoTechDropShadowOpacity),
            blurRadius: kGoTechDropShadowBlur,
            offset: kGoTechDropShadowOffset,
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(kGoTechDropPadding),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children),
              ),
            ),
            Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: kGoTechDropPadding),
              padding: kGoTechDropFooterPadding
                  .add(const EdgeInsets.only(bottom: kGoTechDropPadding)),
              decoration:
                  BoxDecoration(border: Border(top: BorderSide(color: c.line))),
              child: DefaultTextStyle.merge(
                style: TextStyle(fontSize: kGoTechFontTiny, color: c.faint),
                child: const Wrap(
                  spacing: kGoTechDropFooterGap,
                  children: [
                    Text('↑ ↓ seç'),
                    Text('↵ bağlan ya da aç'),
                    Text('esc kapat'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
