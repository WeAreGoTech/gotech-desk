import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/utils/multi_window_manager.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'gotech_api.dart';
import 'gotech_home.dart';
import 'gotech_register.dart';

const _kDialogWidth = 420.0;
const _kLoginDialogTag = 'gotech-login';
// a gotechdesk:// link that started the app is handled once the home page is up
const _kLinkDelay = Duration(seconds: 1);

/// After the first heartbeat: a setup link's installer registers the computer on its own; any other computer
/// that is nobody's yet asks for the sign-in.
Future<void> goTechFirstRun() async {
  if (await goTechInstallDownload()) return;
  if (GoTechRegistration.isRegistered || GoTechRegistration.isTeamMachine) {
    return;
  }
  final token = goTechPresetSetupToken();
  if (token.isNotEmpty) {
    await goTechForgetPresetToken();
    if (await goTechRunSetup(token)) return;
  }
  if (GoTechRegistration.shouldPrompt) showGoTechLoginDialog();
}

/// gotechdesk://kur/<token>: how a Mac gets its setup link, since the app cannot read its disk image's name.
void goTechSetupFromLink(String token) {
  Timer(_kLinkDelay, () => goTechRunSetup(token));
}

/// A setup link's token registers this computer with no password, or opens the sign-in with a team member's
/// e-mail filled in. True when it was handled.
Future<bool> goTechRunSetup(String token) async {
  final result = await goTechSetup(token);
  final email = result.staffEmail;
  if (email != null) {
    showGoTechLoginDialog(email: email);
    return true;
  }
  final error = result.error;
  if (!GoTechRegistration.isRegistered) {
    showToast(error ?? 'Kurulum bağlantısı kullanılamadı.');
    return false;
  }
  gFFI.dialogManager.dismissByTag(_kLoginDialogTag);
  // a warning here means the computer is registered but its unattended password could not be set
  showToast(error ??
      '${[
        GoTechRegistration.companyName.value,
        GoTechRegistration.who
      ].where((s) => s.isNotEmpty).join(' · ')} olarak kaydedildi');
  _installIfPortable();
  return true;
}

/// A one-click setup link should leave the computer installed, not just its account tied: otherwise the
/// portable exe keeps showing the "click Install" banner on every start. Same gating as that banner
/// (desktop_home_page.dart), triggered automatically instead of waiting for the person to notice it.
void _installIfPortable() {
  if (!isWindows || bind.isDisableInstallation() || bind.mainIsInstalled()) {
    return;
  }
  Timer(_kLinkDelay, () async {
    await rustDeskWinManager.closeAllSubWindows();
    bind.mainGotoInstall();
  });
}

/// What a computer nobody signed in on asks first: the panel e-mail and password. The account says whose
/// computer it is, so there is no company code to find and no person to pick. A team member is asked whether
/// it is a GoTech computer and can turn it either way: the team also signs in on customers' computers.
void showGoTechLoginDialog({String email = ''}) {
  // one at a time: a second one would sit on top of the first
  gFFI.dialogManager.dismissByTag(_kLoginDialogTag);
  final emailController = TextEditingController(text: email);
  final passwordController = TextEditingController();
  var unattended = bind.mainGetLocalOption(key: kOptionGoTechUnattended) == 'Y';
  GoTechAccount? staff;
  var notice = '';
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

    Future<String?> claimForTeam(GoTechAccount account) async {
      final wasCustomerOf = GoTechRegistration.isRegistered
          ? GoTechRegistration.companyName.value
          : '';
      final err = await goTechClaim(account);
      if (err != null) return err;
      await _keepSignedIn(account);
      finish();
      showToast(wasCustomerOf.isEmpty
          ? 'GoTech ekip bilgisayarı olarak giriş yapıldı'
          : '$wasCustomerOf kaydı kaldırıldı, GoTech ekip bilgisayarı oldu');
      return null;
    }

    // "Hayır": the computer is not GoTech's. It leaves the team list, no team session stays on it, and the
    // sign-in starts over for the customer's account or the company code.
    Future<String?> notTeam(GoTechAccount account) async {
      final err = await goTechReleaseTeam(account);
      if (err != null) return err;
      await goTechSignOut(account.token);
      await _endKeptSession();
      staff = null;
      if (GoTechRegistration.isRegistered) {
        finish();
        showToast(
            '${GoTechRegistration.companyName.value} bilgisayarı olarak kaldı');
        return null;
      }
      passwordController.clear();
      notice = 'Ekip bilgisayarı değil. Müşterinin hesabıyla giriş yapın '
          'ya da firma koduyla kaydedin.';
      return null;
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
                notice: notice,
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
                  onPressed: () => run(() => notTeam(staff!)), isOutline: true),
              dialogButton('Evet, ekip bilgisayarım',
                  onPressed: () => run(() => claimForTeam(staff!))),
            ]
          : [
              dialogButton('Şimdi değil', onPressed: later, isOutline: true),
              dialogButton('Giriş yap', onPressed: () => run(signIn)),
            ],
      onSubmit: () => run(askTeam ? () => claimForTeam(staff!) : signIn),
      onCancel: later,
    );
  }, tag: _kLoginDialogTag);
}

List<Widget> _signInStep({
  required String notice,
  required TextEditingController emailController,
  required TextEditingController passwordController,
  required bool unattended,
  required ValueChanged<bool> onUnattended,
  required bool loading,
  required VoidCallback onSubmit,
  required VoidCallback onCompanyCode,
}) {
  return [
    if (notice.isNotEmpty)
      Text(notice, style: const TextStyle(fontWeight: FontWeight.w600))
          .marginOnly(bottom: 6),
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
    Wrap(
      spacing: 16,
      children: [
        TextButton(
          // also where someone invited but never set a password gets a link
          onPressed: () =>
              launchUrl(Uri.parse('${goTechApiBase()}/sifremi-unuttum')),
          style: TextButton.styleFrom(
              foregroundColor: kGoTechRed, padding: EdgeInsets.zero),
          child: const Text('Şifremi unuttum'),
        ),
        TextButton(
          onPressed: loading ? null : onCompanyCode,
          style: TextButton.styleFrom(
              foregroundColor: kGoTechRed, padding: EdgeInsets.zero),
          child: const Text('Hesabınız yok mu? Firma koduyla kaydolun'),
        ),
      ],
    ),
  ];
}

List<Widget> _teamStep(BuildContext context, String name) {
  final muted = Theme.of(context).textTheme.titleLarge?.color?.withOpacity(0.7);
  // what the answer will change, so turning a computer either way is never a surprise
  final now = GoTechRegistration.isRegistered
      ? 'Şu an ${GoTechRegistration.companyName.value} firmasına kayıtlı; '
          '"Evet" derseniz firma kaydı kaldırılır.'
      : GoTechRegistration.isTeamMachine
          ? 'Şu an GoTech ekip bilgisayarı; "Hayır" derseniz ekip listesinden '
              'çıkar.'
          : 'Ekip bilgisayarı müşteri bilgisayarlarına bağlanabilir ve ekibin '
              'listesinde görünür.';
  return [
    Text('Merhaba $name. Bu bilgisayar GoTech ekibine mi ait?',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
    const SizedBox(height: 10),
    Text('$now Bir müşterinin bilgisayarını kuruyorsanız "Hayır" deyin.',
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

/// A team computer kept its team member signed in for the address book; one that is no longer GoTech's must not.
Future<void> _endKeptSession() async {
  final token = bind.mainGetLocalOption(key: 'access_token');
  if (token.isEmpty) return;
  await goTechSignOut(token);
  await gFFI.userModel.reset(resetOther: true);
}

/// Asks first, then signs this computer out: its registration and any team session on it are dropped, and the
/// sign-in shows again for whoever uses it next.
void showGoTechSignOutDialog() {
  var errMsg = '';
  var loading = false;
  gFFI.dialogManager.show((setState, close, context) {
    Future<void> signOut() async {
      if (loading) return;
      setState(() {
        loading = true;
        errMsg = '';
      });
      final err = await goTechSignOutComputer();
      if (err != null) {
        setState(() {
          loading = false;
          errMsg = err;
        });
        return;
      }
      await _endKeptSession();
      close();
      showToast('Çıkış yapıldı');
      showGoTechLoginDialog();
    }

    void cancel() {
      if (!loading) close();
    }

    return CustomAlertDialog(
      title: Row(
        children: [
          const Icon(Icons.logout_rounded, color: kGoTechRed),
          const Text('Çıkış yap').paddingOnly(left: 10),
        ],
      ),
      content: SizedBox(
        width: _kDialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bu bilgisayarın kaydı kaldırılır. Tekrar destek almak '
                'için hesabınızla yeniden giriş yapmanız gerekir.'),
            if (errMsg.isNotEmpty)
              Text(errMsg, style: const TextStyle(color: kGoTechRed))
                  .marginOnly(top: 8),
            if (loading) const LinearProgressIndicator().marginOnly(top: 8),
          ],
        ),
      ),
      actions: [
        dialogButton('Vazgeç', onPressed: cancel, isOutline: true),
        dialogButton('Çıkış yap', onPressed: signOut),
      ],
      onSubmit: signOut,
      onCancel: cancel,
    );
  });
}
