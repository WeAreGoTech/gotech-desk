import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:get/get.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:provider/provider.dart';

import 'gotech_sidebar_footer_view.dart';
import 'gotech_tokens.dart';

export 'gotech_tokens.dart';

BoxDecoration goTechCardDecoration(BuildContext context) => BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(kGoTechRadius),
      border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.12)),
    );

/// This device's ID and password in one horizontal card, or in two short lines at the foot of the
/// sidebar when [compact].
class GoTechDeviceCard extends StatelessWidget {
  final bool compact;
  const GoTechDeviceCard({Key? key, this.compact = false}) : super(key: key);

  List<Widget> _passwordActions(ServerModel model) {
    final showOneTime = model.approveMode != 'click' &&
        model.verificationMethod != kUsePermanentPassword;
    return [
      if (showOneTime)
        GoTechIconButton(
          icon: Icons.copy_rounded,
          tooltip: translate('Copy'),
          compact: compact,
          onTap: () => _copy(model.serverPasswd.text),
        ),
      if (showOneTime)
        GoTechIconButton(
          icon: Icons.refresh_rounded,
          tooltip: translate('Refresh Password'),
          compact: compact,
          onTap: () => bind.mainUpdateTemporaryPassword(),
        ),
      if (!bind.isDisableSettings())
        GoTechIconButton(
          icon: Icons.edit_outlined,
          tooltip: translate('Change Password'),
          compact: compact,
          onTap: () => DesktopSettingPage.switch2page(SettingsTabKey.safety),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServerModel>(builder: (context, model, _) {
      final copyId = GoTechIconButton(
        icon: Icons.copy_rounded,
        tooltip: translate('Copy'),
        compact: compact,
        onTap: () => _copy(model.serverId.text),
      );
      if (compact) {
        return GoTechCompactIdRows(
          id: model.serverId,
          password: model.serverPasswd,
          idActions: [copyId],
          passwordActions: _passwordActions(model),
        );
      }
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 10, 14),
        decoration: goTechCardDecoration(context),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: _GoTechField(
                  label: translate('ID'),
                  controller: model.serverId,
                  fontSize: 26,
                  actions: [copyId],
                ),
              ),
              VerticalDivider(
                width: 28,
                color: Theme.of(context).dividerColor.withOpacity(0.2),
              ),
              Expanded(
                flex: 4,
                child: _GoTechField(
                  label: translate('One-time Password'),
                  controller: model.serverPasswd,
                  fontSize: 20,
                  actions: _passwordActions(model),
                ),
              ),
              VerticalDivider(
                width: 20,
                color: Theme.of(context).dividerColor.withOpacity(0.2),
              ),
              GoTechIconButton(
                icon: Icons.settings_outlined,
                tooltip: translate('Settings'),
                onTap: DesktopTabPage.onAddSetting,
              ),
            ],
          ),
        ),
      );
    });
  }

  static void _copy(String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    showToast(translate('Copied'));
  }
}

class _GoTechField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final double fontSize;
  final List<Widget> actions;

  const _GoTechField({
    required this.label,
    required this.controller,
    required this.fontSize,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.titleLarge?.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: textColor?.withOpacity(0.55)),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) => Text(
                  value.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            ...actions,
          ],
        ),
      ],
    );
  }
}

/// Slim banner replacing the tall side-pane help card.
class GoTechNoticeCard extends StatelessWidget {
  final String title;
  final String content;
  final String btnText;
  final GestureTapCallback onPressed;
  final String? help;
  final GestureTapCallback? onHelp;
  final VoidCallback? onClose;

  const GoTechNoticeCard({
    Key? key,
    required this.title,
    required this.content,
    required this.btnText,
    required this.onPressed,
    this.help,
    this.onHelp,
    this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kGoTechRadius),
        gradient: const LinearGradient(
          colors: [Color(0xFFE2463B), Color(0xFFF07A45)],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(translate(title),
                      style: const TextStyle(
                          color: white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                if (content.isNotEmpty)
                  Text(translate(content),
                      style: const TextStyle(
                          color: white, fontSize: 12, height: 1.35)),
                if (help != null && onHelp != null)
                  InkWell(
                    onTap: onHelp,
                    child: Text(translate(help!),
                        style: const TextStyle(
                            color: white,
                            fontSize: 12,
                            decoration: TextDecoration.underline)),
                  ).marginOnly(top: 2),
              ],
            ),
          ),
          if (btnText.isNotEmpty)
            OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: white,
                side: const BorderSide(color: white),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(translate(btnText)),
            ).marginOnly(left: 12, right: 4),
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close, color: white, size: 18),
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}
