import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'gotech_tokens.dart';

// Small shared pieces of the GoTech main window: dots, the "⋯" and "Bağlan" buttons, the empty note.

/// Green filled dot when online, hollow gray when not.
class GoTechStatusDot extends StatelessWidget {
  final bool online;
  final double size;
  const GoTechStatusDot(
      {Key? key, required this.online, this.size = kGoTechDotSize})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = GoTechColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: online ? kGoTechOnline : null,
        border: Border.all(
            color: online ? kGoTechOnline : c.faint, width: kGoTechDotBorder),
      ),
    );
  }
}

/// A company color dot.
class GoTechColorDot extends StatelessWidget {
  final Color color;
  final double size;
  const GoTechColorDot(
      {Key? key, required this.color, this.size = kGoTechDotSize})
      : super(key: key);

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

/// The "⋯" button; [onTap] gets the global tap position for the menu.
class GoTechMoreButton extends StatelessWidget {
  final void Function(Offset globalPosition)? onTap;
  final String tooltip;
  const GoTechMoreButton(
      {Key? key, required this.onTap, this.tooltip = 'Diğer işlemler'})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = GoTechColors.of(context);
    var position = Offset.zero;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(kGoTechMoreRadius),
        hoverColor: c.raised,
        onTapDown: (d) => position = d.globalPosition,
        onTap: onTap == null ? null : () => onTap!(position),
        child: SizedBox(
          width: kGoTechMoreButtonSize,
          height: kGoTechMoreButtonSize,
          child: Icon(Icons.more_horiz_rounded,
              size: kGoTechNavIconSize, color: c.muted),
        ),
      ),
    );
  }
}

/// The small red "Bağlan" of a row.
class GoTechRowConnectButton extends StatelessWidget {
  final VoidCallback onPressed;
  const GoTechRowConnectButton({Key? key, required this.onPressed})
      : super(key: key);

  @override
  Widget build(BuildContext context) => SizedBox(
        height: kGoTechRowButtonHeight,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: kGoTechRed,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: kGoTechRowButtonPadding,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kGoTechRowButtonRadius)),
          ),
          child: const Text('Bağlan',
              style: TextStyle(
                  fontSize: kGoTechFontSmall, fontWeight: FontWeight.w600)),
        ),
      );
}

/// Shown in the box when nothing matches.
class GoTechEmptyView extends StatelessWidget {
  final String title;
  final String hint;
  const GoTechEmptyView({Key? key, required this.title, this.hint = ''})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = GoTechColors.of(context);
    return Padding(
      padding: kGoTechEmptyPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: kGoTechFontBody, fontWeight: FontWeight.w600)),
          if (hint.isNotEmpty)
            Text(hint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: kGoTechFontSmall,
                        color: c.muted,
                        height: kGoTechLineHeight))
                .paddingOnly(top: kGoTechDropGap),
        ],
      ),
    );
  }
}
