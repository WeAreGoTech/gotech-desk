import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'gotech_api.dart';
import 'gotech_home.dart';
import 'gotech_login.dart';

const _kMenuWidth = 260.0;
const _kAvatarRadius = 14.0;

enum _AccountAction { panel, switchAccount, signOut }

/// Who this computer belongs to, always in sight, with the panel, another account and signing out one click
/// away. A computer nobody signed in on gets a plain "Giriş yap" instead.
class GoTechAccountButton extends StatelessWidget {
  const GoTechAccountButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final registered = GoTechRegistration.isRegistered;
      final team = GoTechRegistration.isTeamMachine;
      if (!registered && !team) {
        return TextButton.icon(
          onPressed: showGoTechLoginDialog,
          style: TextButton.styleFrom(foregroundColor: kGoTechRed),
          icon: const Icon(Icons.login_rounded, size: 18),
          label: const Text('Giriş yap'),
        );
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
        offset: const Offset(0, 40),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Avatar(name: name),
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
        _Avatar(name: name),
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

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: _kAvatarRadius,
      backgroundColor: kGoTechRed,
      child: Text(initial,
          style: const TextStyle(color: Colors.white, fontSize: 13)),
    );
  }
}
