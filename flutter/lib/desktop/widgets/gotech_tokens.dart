import 'package:flutter/material.dart';

// GoTech sizes and colors. consts.dart re-exports this file. It imports nothing but Flutter, so the
// widget tests can load the GoTech views without the native bridge.

const kGoTechRed = Color(0xFFE2463B);
const kGoTechRadius = 14.0;

// main window: sidebar + main area
const kGoTechOnline = Color(0xFF3FB950);
const kGoTechFocus = Color(0xFF4A8EEA);
const kGoTechStatusError = Color(0xFFE04F5F);
const kGoTechLineOpacity = 0.12;
const kGoTechMutedOpacity = 0.62;
const kGoTechFaintOpacity = 0.42;
const kGoTechSidebarTint = 0.03;
const kGoTechHoverOpacity = 0.55;
const kGoTechDimOpacity = 0.38;

const kGoTechSidebarWidth = 256.0;
const kGoTechSidebarPadding = EdgeInsets.fromLTRB(14, 18, 14, 10);
const kGoTechSidebarGap = 16.0;
const kGoTechLogoHeight = 30.0;
const kGoTechNavPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 8);
const kGoTechNavRadius = 8.0;
const kGoTechNavGap = 2.0;
const kGoTechNavIconSize = 16.0;
const kGoTechCompanyIndent = 12.0;
const kGoTechCompanyGuidePadding = 4.0;
const kGoTechCompanyPadding = EdgeInsets.symmetric(horizontal: 9, vertical: 8);
const kGoTechCompanyHeaderPadding = EdgeInsets.fromLTRB(9, 10, 9, 4);
const kGoTechCompanyRadius = 7.0;
const kGoTechCompanyDotTop = 5.0;
const kGoTechFooterPadding = EdgeInsets.fromLTRB(10, 10, 0, 6);
const kGoTechFooterLabelWidth = 54.0;
const kGoTechAccountPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 6);
const kGoTechAccountRadius = 9.0;
const kGoTechAvatarRadius = 14.0;

// banners above the connect row keep their own top margin, so the main area starts a bit higher
const kGoTechMainPadding = EdgeInsets.fromLTRB(20, 8, 20, 0);
const kGoTechBannerGap = 10.0;
const kGoTechConnectGap = 14.0;
const kGoTechToolbarHeight = 34.0;
const kGoTechToolbarRadius = 9.0;
const kGoTechToolbarGap = 10.0;
const kGoTechBoxRadius = 12.0;
const kGoTechBoxBottom = 16.0;
const kGoTechBoxHeaderPadding = EdgeInsets.fromLTRB(14, 12, 10, 11);
const kGoTechColumnHeaderPadding =
    EdgeInsets.symmetric(horizontal: 14, vertical: 7);
const kGoTechRowPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 8);
const kGoTechColumnGap = 10.0;
const kGoTechStatusColumnWidth = 18.0;
const kGoTechIdColumnWidth = 108.0;
const kGoTechSeenColumnWidth = 96.0;
const kGoTechActionsColumnWidth = 104.0;
const kGoTechRowButtonHeight = 26.0;
const kGoTechRowButtonPadding = EdgeInsets.symmetric(horizontal: 12);
const kGoTechRowButtonRadius = 7.0;
const kGoTechMoreButtonSize = 26.0;
const kGoTechMoreRadius = 6.0;
const kGoTechDotSize = 8.0;
const kGoTechSmallDotSize = 6.0;
const kGoTechDotBorder = 1.5;
const kGoTechPlatformIconSize = 12.0;
const kGoTechFocusWidth = 2.0;
const kGoTechEmptyPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 40);

// connect field dropdown
const kGoTechDropRadius = 12.0;
const kGoTechDropPadding = 6.0;
const kGoTechDropGap = 6.0;
const kGoTechDropMaxHeight = 352.0;
const kGoTechDropMinWidth = 360.0;
const kGoTechDropItemPadding =
    EdgeInsets.symmetric(horizontal: 10, vertical: 8);
const kGoTechDropSectionPadding = EdgeInsets.fromLTRB(10, 8, 10, 4);
const kGoTechDropFooterPadding = EdgeInsets.fromLTRB(10, 8, 10, 3);
const kGoTechDropItemRadius = 8.0;
const kGoTechDropShadowBlur = 40.0;
const kGoTechDropShadowOffset = Offset(0, 18);
const kGoTechDropShadowOpacity = 0.55;
const kGoTechDropFooterGap = 16.0;
const kGoTechKeyHintRadius = 5.0;
const kGoTechKeyHintPadding = EdgeInsets.symmetric(horizontal: 6, vertical: 1);

// font sizes
const kGoTechFontTitle = 15.0;
const kGoTechFontBody = 13.0;
const kGoTechFontId = 12.5;
const kGoTechFontSmall = 12.0;
const kGoTechFontTiny = 11.5;
const kGoTechFontKey = 11.0;
const kGoTechFontValue = 15.0;
const kGoTechLineHeight = 1.35;

/// Colors of the GoTech main window, taken from the app theme so light and dark both work.
class GoTechColors {
  final Color fg;
  final Color muted;
  final Color faint;
  final Color line;
  final Color raised;
  final Color hover;
  final Color sidebar;
  final Color surface;
  final Color background;

  const GoTechColors._({
    required this.fg,
    required this.muted,
    required this.faint,
    required this.line,
    required this.raised,
    required this.hover,
    required this.sidebar,
    required this.surface,
    required this.background,
  });

  factory GoTechColors.of(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.textTheme.titleLarge?.color ?? theme.colorScheme.onSurface;
    final background = theme.scaffoldBackgroundColor;
    return GoTechColors._(
      fg: fg,
      muted: fg.withOpacity(kGoTechMutedOpacity),
      faint: fg.withOpacity(kGoTechFaintOpacity),
      line: theme.dividerColor.withOpacity(kGoTechLineOpacity),
      raised: theme.hoverColor,
      hover: theme.hoverColor.withOpacity(kGoTechHoverOpacity),
      sidebar: Color.alphaBlend(fg.withOpacity(kGoTechSidebarTint), background),
      surface: theme.cardColor,
      background: background,
    );
  }
}
