import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'gotech_api.dart';
import 'gotech_home.dart';
import 'gotech_login.dart';
import 'gotech_sidebar_footer_view.dart';

const _kMenuWidth = 260.0;

enum _AccountAction { panel, switchAccount, signOut }

/// Who this computer belongs to, always in sight, with the panel, another account and signing out one click
/// away. A computer nobody signed in on gets a plain "Giriş yap" instead.
class GoTechAccountButton extends StatelessWidget {
  /// A full-width row (avatar, name, chevron) for the foot of the sidebar.
  final bool expanded;
  const GoTechAccountButton({Key? key, this.expanded = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final registered = GoTechRegistration.isRegistered;
      final team = GoTechRegistration.isTeamMachine;
      if (!registered && !team) {
        final button = TextButton.icon(
          onPressed: showGoTechLoginDialog,
          style: TextButton.styleFrom(foregroundColor: kGoTechRed),
          icon: const Icon(Icons.login_rounded, size: 18),
          label: const Text('Giriş yap'),
        );
        return expanded
            ? Align(alignment: Alignment.centerLeft, child: button)
            : button;
      }
      final name = registered
          ? (GoTechRegistration.personName.value.isNotEmpty
              ? GoTechRegistration.personName.value
              : GoTechRegistration.companyName.value)
          : GoTechRegistration.teamOwner.value;
      final company =
          registered ? GoTechRegistration.companyName.value : 'GoTech ekibi';
      final email = GoTechRegistration.email.value;
      return PopupMenuButton<_AccountAction>(
        tooltip: 'Hesap',
        // at the foot of the sidebar the menu opens upwards
        offset: expanded ? Offset.zero : const Offset(0, 40),
        position: expanded ? PopupMenuPosition.over : null,
        constraints: const BoxConstraints(minWidth: _kMenuWidth),
        onSelected: (action) {
          switch (action) {
            case _AccountAction.panel:
              launchUrl(Uri.parse(
                  '${goTechApiBase()}${registered ? '/panel' : '/yonetim'}'));
            case _AccountAction.switchAccount:
              showGoTechLoginDialog();
            case _AccountAction.signOut:
              showGoTechSignOutDialog();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            enabled: false,
            child: _AccountHeader(name: name, email: email, company: company),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: _AccountAction.panel,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.open_in_new_rounded),
              title: Text('Panele git'),
            ),
          ),
          const PopupMenuItem(
            value: _AccountAction.switchAccount,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.switch_account_rounded),
              title: Text('Hesap değiştir'),
            ),
          ),
          const PopupMenuItem(
            value: _AccountAction.signOut,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.logout_rounded, color: kGoTechRed),
              title: Text('Çıkış yap', style: TextStyle(color: kGoTechRed)),
            ),
          ),
        ],
        child: expanded
            ? GoTechAccountRowView(name: name)
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GoTechAvatar(name: name),
                    const SizedBox(width: 8),
                    Text(name, style: const TextStyle(fontSize: 13)),
                    const Icon(Icons.arrow_drop_down_rounded),
                  ],
                ),
              ),
      );
    });
  }
}

class _AccountHeader extends StatelessWidget {
  final String name;
  final String email;
  final String company;
  const _AccountHeader(
      {required this.name, required this.email, required this.company});

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).textTheme.titleLarge?.color?.withOpacity(0.6);
    return Row(
      children: [
        GoTechAvatar(name: name),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.titleLarge?.color)),
              if (email.isNotEmpty)
                Text(email, style: TextStyle(fontSize: 12, color: muted)),
              Text(company, style: TextStyle(fontSize: 12, color: muted)),
            ],
          ),
        ),
      ],
    );
  }
}
