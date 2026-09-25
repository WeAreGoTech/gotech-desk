import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

import 'gotech_account_menu.dart';
import 'gotech_api.dart';
import 'gotech_home.dart';
import 'gotech_login.dart';
import 'gotech_register.dart';
import 'gotech_sessions_view.dart';

const _kSimpleHomeWidth = 520.0;
const _kMainButtonHeight = 54.0;

/// The whole screen of a customer's computer, and of one nobody has signed in on yet: a single way to
/// ask for help (or to sign in first) and the ID and password to read out on the phone. The connect bar
/// and the peer lists stay on the team's computers.
class GoTechSimpleHome extends StatelessWidget {
  /// Warnings the home page owns: the preset password, install and permission cards.
  final Widget notices;

  const GoTechSimpleHome({Key? key, required this.notices}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: _kSimpleHomeWidth),
                      child: Column(
                        children: [
                          loadPowered(context),
                          loadLogo(),
                          const SizedBox(height: 18),
                          const GoTechActiveSessionsCard(),
                          Obx(() => GoTechRegistration.isRegistered
                              ? const _SupportCard()
                              : const _SignInCard()),
                          const SizedBox(height: 14),
                          const GoTechDeviceCard(),
                          const _AccessNote(),
                          Obx(() => GoTechRegistration.isRegistered
                              ? const GoTechHistoryCard()
                              : const SizedBox.shrink()),
                          const GoTechUpdateBar(),
                          notices,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned(top: 8, right: 12, child: GoTechAccountButton()),
            ],
          ),
        ),
        const Divider(height: 1),
        OnlineStatusWidget(),
      ],
    );
  }
}

class _MainCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String action;
  final VoidCallback onAction;
  final String link;
  final VoidCallback onLink;

  const _MainCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.action,
    required this.onAction,
    required this.link,
    required this.onLink,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.titleLarge?.color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      decoration: goTechCardDecoration(context),
      child: Column(
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 13, color: textColor?.withOpacity(0.65))),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: _kMainButtonHeight,
            child: ElevatedButton.icon(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: kGoTechRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(icon, size: 22),
              label: Text(action,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600)),
            ),
          ),
          TextButton(
            onPressed: onLink,
            style: TextButton.styleFrom(
                foregroundColor: textColor?.withOpacity(0.6)),
            child: Text(link, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard();

  @override
  Widget build(BuildContext context) {
    return Obx(() => _MainCard(
          title: [GoTechRegistration.companyName.value, GoTechRegistration.who]
              .where((s) => s.isNotEmpty)
              .join(' · '),
          subtitle:
              'Bir sorun mu var? Yazın, GoTech ekibi bilgisayarınıza bağlanıp yardım etsin.',
          icon: Icons.support_agent_rounded,
          action: 'Destek iste',
          onAction: showGoTechSupportDialog,
          link: 'Çıkış yap',
          onLink: showGoTechSignOutDialog,
        ));
  }
}

class _SignInCard extends StatelessWidget {
  const _SignInCard();

  @override
  Widget build(BuildContext context) {
    return const _MainCard(
      title: 'GoTech Desk\'e hoş geldiniz',
      subtitle:
          'GoTech hesabınızla giriş yapın; bilgisayarınız firmanıza kaydolsun, '
          'tek tıkla destek isteyebilin.',
      icon: Icons.login_rounded,
      action: 'Giriş yap',
      onAction: showGoTechLoginDialog,
      link: 'Hesabınız yok mu? Firma koduyla kaydolun',
      onLink: showGoTechRegisterDialog,
    );
  }
}

/// One quiet line under the ID card: who may connect, and not to hand the password to anyone else.
class _AccessNote extends StatelessWidget {
  const _AccessNote();

  @override
  Widget build(BuildContext context) {
    final color =
        Theme.of(context).textTheme.titleLarge?.color?.withOpacity(0.6);
    return Obx(() {
      final parts = <String>[];
      if (GoTechRegistration.isRegistered) {
        parts.add(bind.mainGetLocalOption(key: kOptionGoTechLockToTeam) != 'N'
            ? 'Bu bilgisayara yalnızca GoTech bağlanabilir.'
            : 'Bağlantıları siz onaylarsınız.');
      }
      parts.add('Kimliği ve şifreyi yalnızca GoTech ekibiyle paylaşın.');
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user_outlined, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(parts.join(' '),
                  style: TextStyle(fontSize: 12, color: color)),
            ),
          ],
        ),
      );
    });
  }
}
