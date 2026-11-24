import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'gotech_tokens.dart';
import 'gotech_view_parts.dart';

// The foot of the GoTech sidebar drawn from plain data: this computer's ID and password, the service
// status and the account. Also the small icon button and avatar the other GoTech widgets share.

const _kTabular = [FontFeature.tabularFigures()];
const _kCompactIconSize = 15.0;
const _kIconSize = 18.0;
const _kCompactIconPadding = 5.0;
const _kIconPadding = 7.0;
const _kIconRadius = 8.0;

/// Small icon button used for copy, refresh, edit and settings.
class GoTechIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool compact;

  const GoTechIconButton({
    Key? key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = GoTechColors.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(_kIconRadius),
        onTap: onTap,
        child: Padding(
          padding:
              EdgeInsets.all(compact ? _kCompactIconPadding : _kIconPadding),
          child: Icon(icon,
              size: compact ? _kCompactIconSize : _kIconSize, color: c.muted),
        ),
      ),
    );
  }
}

/// The red circle with the account's initial.
class GoTechAvatar extends StatelessWidget {
  final String name;
  const GoTechAvatar({Key? key, required this.name}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: kGoTechAvatarRadius,
      backgroundColor: kGoTechRed,
      child: Text(initial,
          style:
              const TextStyle(color: Colors.white, fontSize: kGoTechFontBody)),
    );
  }
}

class _CompactRow extends StatelessWidget {
  final String label;
  final ValueListenable<TextEditingValue> value;
  final List<Widget> actions;
  const _CompactRow(
      {required this.label, required this.value, required this.actions});

  @override
  Widget build(BuildContext context) {
    final c = GoTechColors.of(context);
    return Row(children: [
      SizedBox(
        width: kGoTechFooterLabelWidth,
        child: Text(label,
            style: TextStyle(fontSize: kGoTechFontTiny, color: c.faint)),
      ),
      Expanded(
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: value,
          builder: (context, v, _) => Text(v.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: kGoTechFontValue,
                  fontWeight: FontWeight.w600,
                  fontFeatures: _kTabular)),
        ),
      ),
      ...actions,
    ]);
  }
}

/// "Kimliğin" and "Parola" in two short lines at the foot of the sidebar.
class GoTechCompactIdRows extends StatelessWidget {
  final ValueListenable<TextEditingValue> id;
  final ValueListenable<TextEditingValue> password;
  final List<Widget> idActions;
  final List<Widget> passwordActions;

  const GoTechCompactIdRows({
    Key? key,
    required this.id,
    required this.password,
    required this.idActions,
    required this.passwordActions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = GoTechColors.of(context);
    return Container(
      padding: kGoTechFooterPadding,
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
      child: Column(children: [
        _CompactRow(label: 'Kimliğin', value: id, actions: idActions),
        const SizedBox(height: kGoTechNavGap),
        _CompactRow(label: 'Parola', value: password, actions: passwordActions),
      ]),
    );
  }
}

/// "● Hazır, ekip bilgisayarı", with an optional link such as "Başlat".
class GoTechStatusView extends StatelessWidget {
  final Color color;
  final String text;
  final String actionLabel;
  final VoidCallback? onAction;

  const GoTechStatusView({
    Key? key,
    required this.color,
    required this.text,
    this.actionLabel = '',
    this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = GoTechColors.of(context);
    final style = TextStyle(fontSize: kGoTechFontId, color: c.muted);
    return Padding(
      padding: const EdgeInsets.only(left: kGoTechColumnGap),
      child: Row(children: [
        GoTechColorDot(color: color),
        const SizedBox(width: kGoTechSmallDotSize + 1),
        Flexible(
            child: Text(text,
                maxLines: 2, overflow: TextOverflow.ellipsis, style: style)),
        if (onAction != null)
          InkWell(
            onTap: onAction,
            child: Text(actionLabel,
                style: style.copyWith(
                    color: c.fg, decoration: TextDecoration.underline)),
          ).marginOnly(left: kGoTechSmallDotSize),
      ]),
    );
  }
}

/// Avatar, name and a chevron across the sidebar; the account menu wraps it.
class GoTechAccountRowView extends StatelessWidget {
  final String name;
  const GoTechAccountRowView({Key? key, required this.name}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = GoTechColors.of(context);
    return Padding(
      padding: kGoTechAccountPadding,
      child: Row(children: [
        GoTechAvatar(name: name),
        const SizedBox(width: kGoTechColumnGap - 1),
        Expanded(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: kGoTechFontBody, fontWeight: FontWeight.w500)),
        ),
        Icon(Icons.expand_more_rounded, size: _kIconSize, color: c.muted),
      ]),
    );
  }
}
