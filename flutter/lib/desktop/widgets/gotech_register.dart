import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get/get.dart';

import 'gotech_account_menu.dart';
import 'gotech_api.dart';
import 'gotech_home.dart';
import 'gotech_login.dart';

export 'gotech_api.dart'
    show
        GoTechRegistration,
        GoTechUpdate,
        goTechHeartbeat,
        goTechShowsSimpleHome,
        goTechStartHeartbeat,
        isGoTechCustomerMachine;

const _kOtherPerson = '__other__';
const _kSharedComputer = '__shared__';
const _kSupportMessageMaxLength = 2000;
const _kSupportMessageLines = 5;
const _kPeopleListMaxHeight = 240.0;
const _kPeopleListWidth = 440.0;

Widget _whoTile(String title, String value, String? groupValue,
    ValueChanged<String?>? onChanged, IconData icon) {
  return RadioListTile<String>(
    dense: true,
    value: value,
    groupValue: groupValue,
    onChanged: onChanged,
    activeColor: kGoTechRed,
    title: Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(title)),
      ],
    ),
  );
}

void showGoTechRegisterDialog() {
  final saved = bind.mainGetLocalOption(key: kOptionGoTechCustomerCode);
  // an installer named GoTechDesk-799990.exe (or an IT-placed firma.txt) fills this in
  final codeController =
      TextEditingController(text: saved.isNotEmpty ? saved : goTechPresetCompanyCode());
  final nameController = TextEditingController();
  final labelController = TextEditingController();
  var unattended = bind.mainGetLocalOption(key: kOptionGoTechUnattended) == 'Y';
  var lockToTeam = bind.mainGetLocalOption(key: kOptionGoTechLockToTeam) != 'N';
  GoTechLookup? lookup;
  String? who;
  var errMsg = '';
  var loading = false;

  gFFI.dialogManager.show((setState, close, context) {
    Future<void> run(Future<String?> Function() task) async {
      if (loading) return;
      setState(() {
        loading = true;
        errMsg = '';
      });
      final err = await task();
      setState(() {
        loading = false;
        errMsg = err ?? '';
      });
    }

    Future<String?> findCompany() async {
      final code = codeController.text.trim();
      if (code.length != kGoTechCompanyCodeLength) {
        return 'Firma kodu 6 haneli olmalıdır.';
      }
      final result = await goTechLookup(code);
      if (result.error != null) return result.error;
      lookup = result.value;
      who = null;
      return null;
    }

    Future<String?> save() async {
      if (who == null) return 'Bu bilgisayarı kimin kullandığını seçin.';
      final name = nameController.text.trim();
      final label = labelController.text.trim();
      if (who == _kOtherPerson && name.length < 2) return 'Adınızı yazın.';
      if (who == _kSharedComputer && label.isEmpty) {
        return 'Bilgisayar için bir ad yazın (ör. Resepsiyon).';
      }
      await bind.mainSetLocalOption(
          key: kOptionGoTechLockToTeam, value: lockToTeam ? '' : 'N');
      final err = await goTechRegister(
        customerCode: codeController.text.trim(),
        unattended: unattended,
        personId: who == _kOtherPerson || who == _kSharedComputer ? null : who,
        personName: who == _kOtherPerson ? name : null,
        label: who == _kSharedComputer ? label : null,
      );
      if (err == null) {
        await applyGoTechLock();
        close();
        showToast(
            '${GoTechRegistration.companyName.value} olarak kaydedildi');
      }
      return err;
    }

    void later() {
      if (loading) return;
      if (!GoTechRegistration.isRegistered) {
        bind.mainSetLocalOption(key: kOptionGoTechRegisterSkipped, value: 'Y');
      }
      close();
    }

    final step2 = lookup != null;
    return CustomAlertDialog(
      title: Row(
        children: [
          const Icon(Icons.verified_user_outlined, color: kGoTechRed),
          const Text('GoTech müşteri kaydı').paddingOnly(left: 10),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!step2) ..._companyStep(codeController, loading, errMsg,
              () => run(findCompany)),
          if (step2)
            ..._personStep(
              context: context,
              lookup: lookup!,
              who: who,
              onWho: (v) => setState(() => who = v),
              nameController: nameController,
              labelController: labelController,
              unattended: unattended,
              onUnattended: (v) => setState(() => unattended = v),
              lockToTeam: lockToTeam,
              onLock: (v) => setState(() => lockToTeam = v),
              loading: loading,
              errMsg: errMsg,
            ),
          if (loading) const LinearProgressIndicator().marginOnly(top: 8),
        ],
      ),
      actions: step2
          ? [
              dialogButton('Geri',
                  onPressed: () => setState(() {
                        lookup = null;
                        errMsg = '';
                      }),
                  isOutline: true),
              dialogButton('Kaydet', onPressed: () => run(save)),
            ]
          : [
              dialogButton('Şimdi değil', onPressed: later, isOutline: true),
              dialogButton('Devam', onPressed: () => run(findCompany)),
            ],
      onSubmit: () => run(step2 ? save : findCompany),
      onCancel: later,
    );
  });
}

List<Widget> _companyStep(TextEditingController controller, bool loading,
    String errMsg, VoidCallback onSubmit) {
  return [
    const Text('GoTech ekibinin size uzaktan destek verebilmesi için firma '
        'kodunuzu girin. Kodu firma yetkilinizden veya GoTech müşteri '
        'panelindeki "Uzak Destek" sayfasından öğrenebilirsiniz.'),
    const SizedBox(height: 16),
    TextField(
      controller: controller,
      autofocus: true,
      enabled: !loading,
      maxLength: kGoTechCompanyCodeLength,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 22, letterSpacing: 4),
      decoration: InputDecoration(
        labelText: 'Firma kodu',
        counterText: '',
        errorText: errMsg.isEmpty ? null : errMsg,
        errorMaxLines: 3,
      ),
      onSubmitted: (_) => onSubmit(),
    ),
  ];
}

List<Widget> _personStep({
  required BuildContext context,
  required GoTechLookup lookup,
  required String? who,
  required ValueChanged<String?> onWho,
  required TextEditingController nameController,
  required TextEditingController labelController,
  required bool unattended,
  required ValueChanged<bool> onUnattended,
  required bool lockToTeam,
  required ValueChanged<bool> onLock,
  required bool loading,
  required String errMsg,
}) {
  return [
    Row(
      children: [
        const Icon(Icons.business_rounded, color: Colors.green, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(lookup.companyName,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
    const SizedBox(height: 16),
    Text('Bu bilgisayarı kim kullanıyor?',
            style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.color
                    ?.withOpacity(0.7)))
        .marginOnly(bottom: 4),
    // AlertDialog sizes its content with IntrinsicWidth, which a ListView
    // cannot answer; a tight width short-circuits that query.
    Container(
      width: _kPeopleListWidth,
      constraints: const BoxConstraints(maxHeight: _kPeopleListMaxHeight),
      decoration: goTechCardDecoration(context),
      child: ListView(
        shrinkWrap: true,
        children: [
          ...lookup.people.map((p) => _whoTile(p.displayName, p.id, who,
              loading ? null : onWho, Icons.person_outline_rounded)),
          _whoTile('Listede adım yok', _kOtherPerson, who,
              loading ? null : onWho, Icons.person_add_alt_rounded),
          _whoTile('Ortak bilgisayar (ör. Resepsiyon)', _kSharedComputer, who,
              loading ? null : onWho, Icons.groups_outlined),
        ],
      ),
    ),
    if (who == _kOtherPerson)
      TextField(
        controller: nameController,
        enabled: !loading,
        decoration: const InputDecoration(labelText: 'Adınız ve soyadınız'),
      ).marginOnly(top: 8),
    if (who == _kSharedComputer)
      TextField(
        controller: labelController,
        enabled: !loading,
        maxLength: 60,
        decoration: const InputDecoration(
            labelText: 'Bilgisayarın adı', hintText: 'Resepsiyon, Kasa…'),
      ).marginOnly(top: 8),
    if (errMsg.isNotEmpty)
      Text(errMsg, style: const TextStyle(color: kGoTechRed))
          .marginOnly(top: 8),
    const SizedBox(height: 8),
    CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: lockToTeam,
      onChanged: loading ? null : (v) => onLock(v ?? false),
      title: const Text('Yalnızca GoTech bağlanabilsin'),
      subtitle: const Text(
          'Bu bilgisayara sadece GoTech ekibinin bilgisayarları bağlanabilir, '
          'başka kimse deneyemez.'),
    ),
    CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: unattended,
      onChanged: loading ? null : (v) => onUnattended(v ?? false),
      title: const Text('Gözetimsiz erişime izin ver'),
      subtitle: const Text(
          'GoTech, siz bilgisayar başında olmasanız da bağlanabilir. '
          'Kapalıysa her bağlantıyı ekranınızda siz onaylarsınız.'),
    ),
  ];
}

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
                'İndirip kurduğunuzda ayarlarınız korunur.',
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            ElevatedButton(
              onPressed: () => launchUrl(Uri.parse(GoTechUpdate.url.value)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kGoTechRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('İndir'),
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
                        Text(
                          'Firma kodu ${GoTechRegistration.customerCode.value}',
                          style: TextStyle(
                              fontSize: 11, color: textColor?.withOpacity(0.5)),
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
