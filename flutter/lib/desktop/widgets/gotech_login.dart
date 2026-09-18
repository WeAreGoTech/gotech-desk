import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

import 'gotech_api.dart';
import 'gotech_home.dart';
import 'gotech_register.dart';

const _kDialogWidth = 420.0;

/// What a computer nobody signed in on asks first: the panel e-mail and password. The account says whose
/// computer it is, so there is no company code to find and no person to pick. A team member is asked once
/// whether it is a GoTech computer, since the team also signs in on customers' computers to set them up.
void showGoTechLoginDialog() {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  var unattended = bind.mainGetLocalOption(key: kOptionGoTechUnattended) == 'Y';
  GoTechAccount? staff;
  var errMsg = '';
  var loading = false;
  var closed = false;

  gFFI.dialogManager.show((setState, close, context) {
    void finish() {
      closed = true;
      close();
    }

    Future<void> run(Future<String?> Function() task) async {
      if (loading) return;
      setState(() {
        loading = true;
        errMsg = '';
      });
      final err = await task();
      if (closed) return;
      setState(() {
        loading = false;
        errMsg = err ?? '';
      });
    }

    Future<String?> signIn() async {
      final email = emailController.text.trim();
      if (email.isEmpty || passwordController.text.isEmpty) {
        return 'E-posta adresinizi ve şifrenizi yazın.';
      }
      final result = await goTechSignIn(email, passwordController.text);
      final account = result.value;
      if (account == null) return result.error;
      if (account.isStaff) {
        staff = account;
        return null;
      }
      final err = await goTechClaim(account, unattended: unattended);
      // from now on the device token speaks for this computer; a customer's session is not kept on it
      await goTechSignOut(account.token);
      if (err != null) return err;
      finish();
      showToast('${GoTechRegistration.companyName.value} olarak kaydedildi');
      return null;
    }

    Future<String?> claimForTeam() async {
      final account = staff!;
      final err = await goTechClaim(account);
      if (err != null) return err;
      await _keepSignedIn(account);
      finish();
      showToast('GoTech ekip bilgisayarı olarak kaydedildi');
      return null;
    }

    void useCompanyCode() {
      if (loading) return;
      final account = staff;
      if (account != null) goTechSignOut(account.token);
      finish();
      showGoTechRegisterDialog();
    }

    void later() {
      if (loading) return;
      final account = staff;
      if (account != null) goTechSignOut(account.token);
      if (GoTechRegistration.shouldPrompt) {
        bind.mainSetLocalOption(key: kOptionGoTechRegisterSkipped, value: 'Y');
      }
      finish();
    }

    final askTeam = staff != null;
    return CustomAlertDialog(
      title: Row(
        children: [
          Icon(askTeam ? Icons.shield_outlined : Icons.login_rounded,
              color: kGoTechRed),
          Text(askTeam ? 'GoTech ekip bilgisayarı' : 'GoTech\'e giriş')
              .paddingOnly(left: 10),
        ],
      ),
      content: SizedBox(
        width: _kDialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (askTeam)
              ..._teamStep(context, staff!.name)
            else
              ..._signInStep(
                emailController: emailController,
                passwordController: passwordController,
                unattended: unattended,
                onUnattended: (v) => setState(() => unattended = v),
                loading: loading,
                onSubmit: () => run(signIn),
                onCompanyCode: useCompanyCode,
              ),
            if (errMsg.isNotEmpty)
              Text(errMsg, style: const TextStyle(color: kGoTechRed))
                  .marginOnly(top: 8),
            if (loading) const LinearProgressIndicator().marginOnly(top: 8),
          ],
        ),
      ),
      actions: askTeam
          ? [
              dialogButton('Hayır, müşteri bilgisayarı',
                  onPressed: useCompanyCode, isOutline: true),
              dialogButton('Evet, ekip bilgisayarım',
                  onPressed: () => run(claimForTeam)),
            ]
          : [
              dialogButton('Şimdi değil', onPressed: later, isOutline: true),
              dialogButton('Giriş yap', onPressed: () => run(signIn)),
            ],
      onSubmit: () => run(askTeam ? claimForTeam : signIn),
      onCancel: later,
    );
  });
}

List<Widget> _signInStep({
  required TextEditingController emailController,
  required TextEditingController passwordController,
  required bool unattended,
  required ValueChanged<bool> onUnattended,
  required bool loading,
  required VoidCallback onSubmit,
  required VoidCallback onCompanyCode,
}) {
  return [
    const Text(
        'GoTech panelindeki e-posta adresiniz ve şifrenizle giriş yapın. '
        'Bilgisayarınız firmanıza kendiliğinden kaydolur.'),
    const SizedBox(height: 8),
    TextField(
      controller: emailController,
      autofocus: true,
      enabled: !loading,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(labelText: 'E-posta'),
      onSubmitted: (_) => onSubmit(),
    ),
    TextField(
      controller: passwordController,
      enabled: !loading,
      obscureText: true,
      decoration: const InputDecoration(labelText: 'Şifre'),
      onSubmitted: (_) => onSubmit(),
    ),
    const SizedBox(height: 8),
    CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: unattended,
      onChanged: loading ? null : (v) => onUnattended(v ?? false),
      title: const Text('Gözetimsiz erişime izin ver'),
      subtitle:
          const Text('Siz bilgisayar başında değilken de GoTech bağlanabilir.'),
    ),
    TextButton(
      onPressed: loading ? null : onCompanyCode,
      style: TextButton.styleFrom(
          foregroundColor: kGoTechRed, padding: EdgeInsets.zero),
      child: const Text('Hesabınız yok mu? Firma koduyla kaydolun'),
    ),
  ];
}

List<Widget> _teamStep(BuildContext context, String name) {
  final muted = Theme.of(context).textTheme.titleLarge?.color?.withOpacity(0.7);
  return [
    Text('Merhaba $name. Bu bilgisayar GoTech ekibine mi ait?',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
    const SizedBox(height: 10),
    Text(
        'Ekip bilgisayarı müşteri bilgisayarlarına bağlanabilir ve ekibin '
        'listesinde görünür. Bir müşterinin bilgisayarını kuruyorsanız "Hayır" '
        'deyin ve firma koduyla kaydedin.',
        style: TextStyle(fontSize: 13, color: muted)),
  ];
}

/// A team member stays signed in, as with RustDesk's own login, so the address book fills from the panel.
Future<void> _keepSignedIn(GoTechAccount account) async {
  await bind.mainSetLocalOption(key: 'access_token', value: account.token);
  await bind.mainSetLocalOption(
      key: 'user_info', value: jsonEncode(account.user));
  gFFI.userModel.refreshCurrentUser();
}
