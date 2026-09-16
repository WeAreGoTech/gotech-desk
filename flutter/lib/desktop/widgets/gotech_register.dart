import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/utils/http_service.dart' as http;
import 'package:get/get.dart';

import 'gotech_home.dart';

// Temporary sslip.io address until GoTech has a domain.
const kGoTechApiBase =
    'https://gotech-web-3biyyk-fc72c7-152-53-142-222.sslip.io';

const kOptionGoTechApiUrl = 'gotech-api-url';
const kOptionGoTechCustomerCode = 'gotech-customer-code';
const kOptionGoTechCompanyName = 'gotech-company-name';
const kOptionGoTechUnattended = 'gotech-unattended';
const kOptionGoTechRegisterSkipped = 'gotech-register-skipped';

const _kCustomerCodeLength = 6;
const _kUnattendedPasswordLength = 20;
const _kPasswordChars =
    'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const _kRequestTimeout = Duration(seconds: 15);

/// Registration state shown on the home page.
class GoTechRegistration {
  static final customerCode = ''.obs;
  static final companyName = ''.obs;

  static void load() {
    customerCode.value = bind.mainGetLocalOption(key: kOptionGoTechCustomerCode);
    companyName.value = bind.mainGetLocalOption(key: kOptionGoTechCompanyName);
  }

  static bool get isRegistered => customerCode.value.isNotEmpty;

  static bool get shouldPrompt =>
      !isRegistered &&
      bind.mainGetLocalOption(key: kOptionGoTechRegisterSkipped) != 'Y';
}

String goTechApiBase() {
  final custom = bind.mainGetLocalOption(key: kOptionGoTechApiUrl).trim();
  return custom.isNotEmpty ? custom : kGoTechApiBase;
}

String _generatePassword() {
  final random = Random.secure();
  return List.generate(_kUnattendedPasswordLength,
      (_) => _kPasswordChars[random.nextInt(_kPasswordChars.length)]).join();
}

/// Registers this device to the customer on the GoTech website.
/// Returns an error message, or null on success.
Future<String?> goTechRegister(
    {required String customerCode, required bool unattended}) async {
  final wasUnattended =
      bind.mainGetLocalOption(key: kOptionGoTechUnattended) == 'Y';
  final password = unattended ? _generatePassword() : null;
  if (password != null || wasUnattended) {
    final ok = await bind.mainSetPermanentPasswordWithResult(
        password: password ?? '');
    if (!ok) return 'Kalıcı şifre ayarlanamadı.';
  }

  Future<void> revertPassword() async {
    if (password != null && !wasUnattended) {
      await bind.mainSetPermanentPasswordWithResult(password: '');
    }
  }

  try {
    final deskId = (await bind.mainGetMyId()).replaceAll(' ', '');
    final resp = await http
        .post(
          Uri.parse('${goTechApiBase()}/api/desk/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'customerCode': customerCode,
            'deskId': deskId,
            'hostname': Platform.localHostname,
            'platform': Platform.operatingSystem,
            'appVersion': await bind.mainGetVersion(),
            'unattendedPassword': password,
          }),
        )
        .timeout(_kRequestTimeout);
    final body = jsonDecode(resp.body);
    if (resp.statusCode == 200 && body is Map && body['ok'] == true) {
      final companyName = body['companyName']?.toString() ?? '';
      await bind.mainSetLocalOption(
          key: kOptionGoTechCustomerCode, value: customerCode);
      await bind.mainSetLocalOption(
          key: kOptionGoTechCompanyName, value: companyName);
      await bind.mainSetLocalOption(
          key: kOptionGoTechUnattended, value: unattended ? 'Y' : '');
      GoTechRegistration.load();
      return null;
    }
    await revertPassword();
    if (body is Map && body['error'] is String) return body['error'];
    return 'Kayıt başarısız (${resp.statusCode}).';
  } catch (e) {
    debugPrint('GoTech register failed: $e');
    await revertPassword();
    return 'GoTech sunucusuna ulaşılamadı. İnternet bağlantınızı kontrol edin.';
  }
}

void showGoTechRegisterDialog() {
  final codeController = TextEditingController(
      text: bind.mainGetLocalOption(key: kOptionGoTechCustomerCode));
  var unattended = bind.mainGetLocalOption(key: kOptionGoTechUnattended) == 'Y';
  var errMsg = '';
  var loading = false;

  gFFI.dialogManager.show((setState, close, context) {
    Future<void> submit() async {
      if (loading) return;
      final code = codeController.text.trim();
      if (code.length != _kCustomerCodeLength) {
        setState(() => errMsg = 'Müşteri numarası 6 haneli olmalıdır.');
        return;
      }
      setState(() {
        loading = true;
        errMsg = '';
      });
      final err =
          await goTechRegister(customerCode: code, unattended: unattended);
      if (err != null) {
        setState(() {
          loading = false;
          errMsg = err;
        });
        return;
      }
      close();
      showToast('${GoTechRegistration.companyName.value} olarak kaydedildi');
    }

    void later() {
      if (loading) return;
      if (!GoTechRegistration.isRegistered) {
        bind.mainSetLocalOption(key: kOptionGoTechRegisterSkipped, value: 'Y');
      }
      close();
    }

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
          const Text(
              'GoTech ekibinin size uzaktan destek verebilmesi için müşteri '
              'numaranızı girin. Numaranızı GoTech müşteri panelinde '
              '"Uzak Destek" sayfasında bulabilirsiniz.'),
          const SizedBox(height: 16),
          TextField(
            controller: codeController,
            autofocus: true,
            enabled: !loading,
            maxLength: _kCustomerCodeLength,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 22, letterSpacing: 4),
            decoration: InputDecoration(
              labelText: 'Müşteri numarası',
              counterText: '',
              errorText: errMsg.isEmpty ? null : errMsg,
              errorMaxLines: 3,
            ),
            onSubmitted: (_) => submit(),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: unattended,
            onChanged: loading
                ? null
                : (v) => setState(() => unattended = v ?? false),
            title: const Text('Gözetimsiz erişime izin ver'),
            subtitle: const Text(
                'GoTech, siz bilgisayar başında olmasanız da bağlanabilir. '
                'Kapalıysa her bağlantıyı ekranınızda siz onaylarsınız.'),
          ),
          if (loading) const LinearProgressIndicator().marginOnly(top: 8),
        ],
      ),
      actions: [
        dialogButton('Şimdi değil', onPressed: later, isOutline: true),
        dialogButton('Kaydet', onPressed: submit),
      ],
      onSubmit: submit,
      onCancel: later,
    );
  });
}

/// One-line status under the device card: registered company or a prompt.
class GoTechRegistrationBar extends StatelessWidget {
  const GoTechRegistrationBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.titleLarge?.color;
    return Obx(() {
      final registered = GoTechRegistration.isRegistered;
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: goTechCardDecoration(context),
        child: Row(
          children: [
            Icon(
              registered ? Icons.verified_rounded : Icons.info_outline_rounded,
              size: 18,
              color: registered ? Colors.green : kGoTechRed,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                registered
                    ? '${GoTechRegistration.companyName.value} · '
                        'Müşteri no ${GoTechRegistration.customerCode.value}'
                    : 'Bu cihaz henüz bir GoTech müşterisine kayıtlı değil.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: textColor),
              ),
            ),
            TextButton(
              onPressed: showGoTechRegisterDialog,
              style: TextButton.styleFrom(foregroundColor: kGoTechRed),
              child: Text(registered ? 'Değiştir' : 'Kayıt ol'),
            ),
          ],
        ),
      );
    });
  }
}
