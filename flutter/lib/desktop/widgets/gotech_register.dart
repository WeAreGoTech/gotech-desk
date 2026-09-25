import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:get/get.dart';

import 'gotech_account_menu.dart';
import 'gotech_api.dart';
import 'gotech_home.dart';
import 'gotech_login.dart';
import 'gotech_update.dart';

export 'gotech_api.dart'
    show
        GoTechRegistration,
        GoTechUpdate,
        goTechHeartbeat,
        goTechShowsSimpleHome,
        goTechStartHeartbeat,
        isGoTechCustomerMachine;

const _kSupportMessageMaxLength = 2000;
const _kSupportMessageLines = 5;

void showGoTechSupportDialog() {
  final messageController = TextEditingController();
  var errMsg = '';
  var loading = false;

  gFFI.dialogManager.show((setState, close, context) {
    Future<void> submit() async {
      if (loading) return;
      final message = messageController.text.trim();
      if (message.isEmpty) {
        setState(() => errMsg = 'Sorununuzu kısaca yazın.');
        return;
      }
      setState(() {
        loading = true;
        errMsg = '';
      });
      final result = await goTechSupportRequest(message);
      if (result.error != null) {
        setState(() {
          loading = false;
          errMsg = result.error!;
        });
        return;
      }
      close();
      showToast('Talebiniz alındı (#${result.value}). '
          'GoTech ekibi en kısa sürede size dönecek.');
    }

    return CustomAlertDialog(
      title: Row(
        children: [
          const Icon(Icons.support_agent_rounded, color: kGoTechRed),
          const Text('GoTech\'ten destek iste').paddingOnly(left: 10),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sorununuzu yazın. Talebiniz bu bilgisayarla birlikte '
              'GoTech ekibine iletilir; gerekirse bilgisayarınıza bağlanırlar.'),
          const SizedBox(height: 12),
          TextField(
            controller: messageController,
            autofocus: true,
            enabled: !loading,
            minLines: _kSupportMessageLines,
            maxLines: _kSupportMessageLines,
            maxLength: _kSupportMessageMaxLength,
            decoration: InputDecoration(
              hintText: 'Ör. Yazıcıdan çıktı alamıyorum…',
              errorText: errMsg.isEmpty ? null : errMsg,
              errorMaxLines: 3,
            ),
          ),
          if (loading) const LinearProgressIndicator().marginOnly(top: 8),
        ],
      ),
      actions: [
        dialogButton('Vazgeç', onPressed: close, isOutline: true),
        dialogButton('Gönder', onPressed: submit),
      ],
      onCancel: close,
    );
  });
}

/// Offers the newer build the panel published.
class GoTechUpdateBar extends StatelessWidget {
  const GoTechUpdateBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!GoTechUpdate.available) return const SizedBox.shrink();
      final inPlace = goTechCanUpdateInPlace;
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kGoTechRadius),
          color: kGoTechRed.withOpacity(0.12),
          border: Border.all(color: kGoTechRed.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.system_update_alt_rounded,
                size: 18, color: kGoTechRed),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Yeni sürüm hazır (${GoTechUpdate.version.value}). '
                '${inPlace ? 'Güncelleyince uygulama kendini yeniden başlatır; ayarlarınız korunur.' : 'İndirip kurduğunuzda ayarlarınız korunur.'}',
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            ElevatedButton(
              onPressed: goTechStartUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: kGoTechRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(inPlace ? 'Güncelle' : 'İndir'),
            ),
          ],
        ),
      );
    });
  }
}

/// One-line status under the device card: registered company or a prompt.
class GoTechRegistrationBar extends StatelessWidget {
  const GoTechRegistrationBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.titleLarge?.color;
    return Obx(() {
      final registered = GoTechRegistration.isRegistered;
      final team = GoTechRegistration.isTeamMachine;
      final who = GoTechRegistration.who;
      // the panel session lapses after 30 days or a password change; the address book then stays empty
      final teamSignedOut = team && gFFI.userModel.userName.value.isEmpty;
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        decoration: goTechCardDecoration(context),
        child: Row(
          children: [
            Icon(
              registered
                  ? Icons.verified_rounded
                  : team
                      ? Icons.shield_rounded
                      : Icons.info_outline_rounded,
              size: 18,
              color: registered || team ? Colors.green : kGoTechRed,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: registered
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [GoTechRegistration.companyName.value, who]
                              .where((s) => s.isNotEmpty)
                              .join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: textColor),
                        ),
                      ],
                    )
                  : team
                      ? Text(
                          // the computer's own name, not the signed-in account: this line says
                          // which machine you are sitting at, which its owner already knows
                          'GoTech ekip bilgisayarı · ${GoTechRegistration.teamLabel.value.isNotEmpty ? GoTechRegistration.teamLabel.value : GoTechRegistration.teamOwner.value}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: textColor),
                        )
                      : Text(
                          'GoTech hesabınızla giriş yapın.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: textColor),
                        ),
            ),
            // a team computer can be turned back into a customer's from here, too
            if (registered || (team && !teamSignedOut))
              const GoTechAccountButton()
            else
              TextButton(
                onPressed: showGoTechLoginDialog,
                style: TextButton.styleFrom(foregroundColor: kGoTechRed),
                child: const Text('Giriş yap'),
              ),
            if (registered)
              ElevatedButton.icon(
                onPressed: showGoTechSupportDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGoTechRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.support_agent_rounded, size: 18),
                label: const Text('Destek iste'),
              ).marginOnly(left: 4),
          ],
        ),
      );
    });
  }
}
