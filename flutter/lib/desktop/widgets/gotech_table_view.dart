import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'gotech_tokens.dart';
import 'gotech_view_parts.dart';

// The peer table of the GoTech main window, drawn from plain data. gotech_peer_row.dart feeds it real peers.

const _kTabular = [FontFeature.tabularFigures()];

/// What one table row shows.
class GoTechRowData {
  final String title;
  final String detail;
  final String company;
  final Color? companyColor;
  final String idText;
  final String seenText;
  final bool online;
  final Widget? platformIcon;

  const GoTechRowData({
    required this.title,
    required this.detail,
    required this.idText,
    required this.seenText,
    required this.online,
    this.company = '',
    this.companyColor,
    this.platformIcon,
  });
}

/// Fixed columns: status | person and computer | ID | last seen | actions.
class _Columns extends StatelessWidget {
  final Widget status;
  final Widget who;
  final Widget id;
  final Widget seen;
  final Widget actions;
  const _Columns(
      {required this.status,
      required this.who,
      required this.id,
      required this.seen,
      required this.actions});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(
              width: kGoTechStatusColumnWidth, child: Center(child: status)),
          const SizedBox(width: kGoTechColumnGap),
          Expanded(child: who),
          const SizedBox(width: kGoTechColumnGap),
          SizedBox(width: kGoTechIdColumnWidth, child: id),
          const SizedBox(width: kGoTechColumnGap),
          SizedBox(width: kGoTechSeenColumnWidth, child: seen),
          const SizedBox(width: kGoTechColumnGap),
          SizedBox(width: kGoTechActionsColumnWidth, child: actions),
        ],
      );
}

/// One peer row. Hover and focus come from the caller, so this stays a plain view.
class GoTechPeerRowView extends StatelessWidget {
  final GoTechRowData data;
  final bool selected;
  final bool hovered;
  final bool focused;
  final VoidCallback onConnect;
  final void Function(Offset globalPosition)? onMore;

  const GoTechPeerRowView({
    Key? key,
    required this.data,
    required this.onConnect,
    this.onMore,
    this.selected = false,
    this.hovered = false,
    this.focused = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = GoTechColors.of(context);
    final detailStyle = TextStyle(
        fontSize: kGoTechFontSmall, color: c.muted, height: kGoTechLineHeight);
    final detail = Text.rich(
      TextSpan(children: [
        if (data.company.isNotEmpty) ...[
          if (data.companyColor != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: GoTechColorDot(
                      color: data.companyColor!, size: kGoTechSmallDotSize)
                  .paddingOnly(right: kGoTechSmallDotSize - 1),
            ),
          TextSpan(text: '${data.company}, '),
        ],
        TextSpan(text: data.detail),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: detailStyle,
    );
    final who = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Flexible(
            child: Text(data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: kGoTechFontBody,
                    fontWeight: FontWeight.w600,
                    height: kGoTechLineHeight)),
          ),
          if (data.platformIcon != null)
            data.platformIcon!.paddingOnly(left: kGoTechSmallDotSize),
        ]),
        const SizedBox(height: 2),
        detail,
      ],
    );
    return Container(
      padding: kGoTechRowPadding,
      decoration: BoxDecoration(
        color: selected ? c.raised : (hovered ? c.hover : null),
        border: focused
            ? Border.all(color: kGoTechFocus, width: kGoTechFocusWidth)
            : Border(bottom: BorderSide(color: c.line)),
      ),
      child: _Columns(
        status: GoTechStatusDot(online: data.online),
        who: who,
        id: Text(data.idText,
            maxLines: 1,
            style: const TextStyle(
                fontSize: kGoTechFontId, fontFeatures: _kTabular)),
        seen: Text(data.seenText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: kGoTechFontSmall,
                color: data.online ? kGoTechOnline : c.muted)),
        actions: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Visibility(
                visible: selected || hovered || focused,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: GoTechRowConnectButton(onPressed: onConnect),
              ),
            ),
            const SizedBox(width: 4),
            GoTechMoreButton(onTap: onMore),
          ],
        ),
      ),
    );
  }
}

/// "Kişi ve bilgisayar | ID | Son görülme" above the rows.
class GoTechColumnHeader extends StatelessWidget {
  const GoTechColumnHeader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = GoTechColors.of(context);
    final style = TextStyle(fontSize: kGoTechFontTiny, color: c.faint);
    return Container(
      padding: kGoTechColumnHeaderPadding,
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: _Columns(
        status: const SizedBox.shrink(),
        who: Text('Kişi ve bilgisayar', style: style),
        id: Text('ID', style: style),
        seen: Text('Son görülme', style: style),
        actions: const SizedBox.shrink(),
      ),
    );
  }
}

/// Title block of the address book box: the company, its counts and a "⋯".
class GoTechBoxTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final void Function(Offset globalPosition)? onMore;
  const GoTechBoxTitle(
      {Key? key, required this.title, required this.subtitle, this.onMore})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = GoTechColors.of(context);
    return Container(
      padding: kGoTechBoxHeaderPadding,
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: kGoTechFontTitle,
                        fontWeight: FontWeight.w600,
                        height: kGoTechLineHeight)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style:
                        TextStyle(fontSize: kGoTechFontSmall, color: c.muted)),
              ],
            ),
          ),
          if (onMore != null)
            GoTechMoreButton(onTap: onMore, tooltip: 'Rehber menüsü'),
        ],
      ),
    );
  }
}

/// The bordered box holding an optional title, the column header and the rows.
class GoTechTableBox extends StatelessWidget {
  final Widget? title;
  final Widget rows;
  const GoTechTableBox({Key? key, this.title, required this.rows})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = GoTechColors.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kGoTechBoxRadius),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) title!,
          const GoTechColumnHeader(),
          Expanded(child: rows),
        ],
      ),
    );
  }
}
