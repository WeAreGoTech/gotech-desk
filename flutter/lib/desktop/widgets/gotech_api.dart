import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/utils/http_service.dart' as http;
import 'package:get/get.dart';

// Temporary sslip.io address until GoTech has a domain.
const kGoTechApiBase =
    'https://gotech-web-3biyyk-fc72c7-152-53-142-222.sslip.io';

const kOptionGoTechApiUrl = 'gotech-api-url';
const kOptionGoTechCustomerCode = 'gotech-customer-code';
const kOptionGoTechCompanyName = 'gotech-company-name';
const kOptionGoTechPersonName = 'gotech-person-name';
const kOptionGoTechLabel = 'gotech-label';
const kOptionGoTechUnattended = 'gotech-unattended';
const kOptionGoTechDeviceToken = 'gotech-device-token';
const kOptionGoTechRegisterSkipped = 'gotech-register-skipped';
const kOptionGoTechTeamOwner = 'gotech-team-owner';
const kOptionGoTechTeamLabel = 'gotech-team-label';
const kOptionGoTechSupportIds = 'gotech-support-ids';
const kOptionGoTechSupportNames = 'gotech-support-names';
const kOptionGoTechLockToTeam = 'gotech-lock-to-team';
const kOptionGoTechLatestVersion = 'gotech-latest-version';
const kOptionGoTechDownloadUrl = 'gotech-download-url';

const kGoTechCompanyCodeLength = 6;
const _kUnattendedPasswordLength = 20;
const _kPasswordChars =
    'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const _kRequestTimeout = Duration(seconds: 15);
const _kHttpOk = 200;
const _kHttpUnauthorized = 401;
const _kUnreachable =
    'GoTech sunucusuna ulaşılamadı. İnternet bağlantınızı kontrol edin.';

class GoTechPerson {
  final String id;
  final String displayName;
  const GoTechPerson(this.id, this.displayName);
}

class GoTechLookup {
  final String companyName;
  final List<GoTechPerson> people;
  const GoTechLookup(this.companyName, this.people);
}

/// Either a value or a user-facing error message.
class GoTechResult<T> {
  final T? value;
  final String? error;
  const GoTechResult.ok(this.value) : error = null;
  const GoTechResult.fail(this.error) : value = null;
}

/// The newest version the panel offers, when it is newer than this build.
class GoTechUpdate {
  static final version = ''.obs;
  static final url = ''.obs;

  static void load() {
    final latest = _get(kOptionGoTechLatestVersion);
    version.value = _isNewer(latest, _currentVersion) ? latest : '';
    url.value = _get(kOptionGoTechDownloadUrl);
  }

  static bool get available => version.value.isNotEmpty && url.value.isNotEmpty;
}

String _currentVersion = '';

/// "1.6.0" > "1.5.0"; anything unparsable counts as not newer.
bool _isNewer(String candidate, String current) {
  final a = candidate.split('.').map(int.tryParse).toList();
  final b = current.split('.').map(int.tryParse).toList();
  if (a.length != 3 || b.length != 3 || a.contains(null) || b.contains(null)) {
    return false;
  }
  for (var i = 0; i < 3; i++) {
    if (a[i]! != b[i]!) return a[i]! > b[i]!;
  }
  return false;
}

/// Name of the GoTech team member sitting at [peerId], or null for anyone else.
String? goTechSupportName(String peerId) {
  final raw = _get(kOptionGoTechSupportNames);
  if (raw.isEmpty) return null;
  try {
    final map = jsonDecode(raw);
    final name = map is Map ? map[peerId.replaceAll(' ', '')] : null;
    return name is String && name.isNotEmpty ? name : null;
  } catch (_) {
    return null;
  }
}

/// True on a computer registered to a customer company, which gets the simplified screen.
bool get isGoTechCustomerMachine =>
    GoTechRegistration.isRegistered && _get('gotech-full-ui') != 'Y';

/// Registration state shown on the home page.
class GoTechRegistration {
  static final customerCode = ''.obs;
  static final companyName = ''.obs;
  static final personName = ''.obs;
  static final label = ''.obs;
  static final teamOwner = ''.obs;
  static final teamLabel = ''.obs;

  static void load() {
    customerCode.value = _get(kOptionGoTechCustomerCode);
    companyName.value = _get(kOptionGoTechCompanyName);
    personName.value = _get(kOptionGoTechPersonName);
    label.value = _get(kOptionGoTechLabel);
    teamOwner.value = _get(kOptionGoTechTeamOwner);
    teamLabel.value = _get(kOptionGoTechTeamLabel);
  }

  /// A GoTech computer: not a customer, known to the panel by the desk ID a team member added.
  static bool get isTeamMachine => !isRegistered && teamOwner.value.isNotEmpty;

  static bool get isRegistered =>
      customerCode.value.isNotEmpty && _get(kOptionGoTechDeviceToken).isNotEmpty;

  static bool get shouldPrompt =>
      !isRegistered && !isTeamMachine && _get(kOptionGoTechRegisterSkipped) != 'Y';

  static String get who =>
      [personName.value, label.value].where((s) => s.isNotEmpty).join(' · ');
}

String _get(String key) => bind.mainGetLocalOption(key: key);

Future<void> _set(String key, String value) =>
    bind.mainSetLocalOption(key: key, value: value);

String goTechApiBase() {
  final custom = _get(kOptionGoTechApiUrl).trim();
  return custom.isNotEmpty ? custom : kGoTechApiBase;
}

String _generatePassword() {
  final random = Random.secure();
  return List.generate(_kUnattendedPasswordLength,
      (_) => _kPasswordChars[random.nextInt(_kPasswordChars.length)]).join();
}

Future<String> _deskId() async =>
    (await bind.mainGetMyId()).replaceAll(' ', '');

/// Posts JSON and returns (statusCode, decoded body map).
Future<(int, Map<String, dynamic>)> _post(
    String path, Map<String, dynamic> payload) async {
  final resp = await http
      .post(
        Uri.parse('${goTechApiBase()}$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      )
      .timeout(_kRequestTimeout);
  final decoded = jsonDecode(resp.body);
  return (
    resp.statusCode,
    decoded is Map<String, dynamic> ? decoded : <String, dynamic>{}
  );
}

String _errorOf(Map<String, dynamic> body, int status) =>
    body['error'] is String ? body['error'] : 'İşlem başarısız ($status).';

String _str(Map<String, dynamic> body, String key) =>
    body[key] is String ? body[key] : '';

Future<GoTechResult<GoTechLookup>> goTechLookup(String customerCode) async {
  try {
    final (status, body) =
        await _post('/api/desk/lookup', {'customerCode': customerCode});
    if (status != _kHttpOk || body['ok'] != true) {
      return GoTechResult.fail(_errorOf(body, status));
    }
    final people = (body['people'] is List ? body['people'] as List : [])
        .whereType<Map>()
        .map((p) => GoTechPerson('${p['id']}', '${p['displayName']}'))
        .toList();
    return GoTechResult.ok(GoTechLookup(_str(body, 'companyName'), people));
  } catch (e) {
    debugPrint('GoTech lookup failed: $e');
    return const GoTechResult.fail(_kUnreachable);
  }
}

/// Registers this device. Exactly one of [personId], [personName], [label]
/// describes who uses it. Returns an error message, or null on success.
Future<String?> goTechRegister({
  required String customerCode,
  required bool unattended,
  String? personId,
  String? personName,
  String? label,
}) async {
  final wasUnattended = _get(kOptionGoTechUnattended) == 'Y';
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
    final (status, body) = await _post('/api/desk/register', {
      'customerCode': customerCode,
      'deskId': await _deskId(),
      'hostname': Platform.localHostname,
      'platform': Platform.operatingSystem,
      'appVersion': await bind.mainGetVersion(),
      'unattendedPassword': password,
      'personId': personId,
      'personName': personName,
      'label': label,
    });
    if (status != _kHttpOk || body['ok'] != true) {
      await revertPassword();
      return _errorOf(body, status);
    }
    await _set(kOptionGoTechCustomerCode, customerCode);
    await _set(kOptionGoTechCompanyName, _str(body, 'companyName'));
    await _set(kOptionGoTechPersonName, _str(body, 'personName'));
    await _set(kOptionGoTechLabel, _str(body, 'label'));
    await _set(kOptionGoTechDeviceToken, _str(body, 'deviceToken'));
    await _set(kOptionGoTechUnattended, unattended ? 'Y' : '');
    GoTechRegistration.load();
    return null;
  } catch (e) {
    debugPrint('GoTech register failed: $e');
    await revertPassword();
    return _kUnreachable;
  }
}

Future<void> _clearRegistration() async {
  for (final key in [
    kOptionGoTechCustomerCode,
    kOptionGoTechCompanyName,
    kOptionGoTechPersonName,
    kOptionGoTechLabel,
    kOptionGoTechDeviceToken,
    kOptionGoTechRegisterSkipped,
  ]) {
    await _set(key, '');
  }
  GoTechRegistration.load();
}

/// Refreshes what the panel knows about this device and what we show.
/// Returns false when the panel no longer knows this device.
/// The company code an installer carried in its file name (GoTechDesk-799990.exe)
/// or that an IT department dropped next to the app, so the customer types nothing.
String goTechPresetCompanyCode() {
  final fromName = RegExp(r'(\d{6})')
      .firstMatch(File(Platform.resolvedExecutable).uri.pathSegments.last);
  if (fromName != null) return fromName.group(1)!;
  for (final path in [
    r'C:\ProgramData\GoTechDesk\firma.txt',
    '/Library/Application Support/GoTechDesk/firma.txt',
  ]) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        final code = RegExp(r'\d{6}').firstMatch(file.readAsStringSync());
        if (code != null) return code.group(0)!;
      }
    } catch (_) {
      // unreadable is the same as absent
    }
  }
  return '';
}

/// A GoTech computer has no device token to authenticate with, so it asks whether the panel
/// knows its desk ID as one of the team's. Answered yes, it skips the customer registration and
/// still gets the support directory and update notice.
Future<void> _askIfTeamMachine() async {
  try {
    final (status, body) = await _post('/api/desk/team', {
      'deskId': await _deskId(),
      'hostname': Platform.localHostname,
      'appVersion': _currentVersion,
    });
    if (status != _kHttpOk) return;
    if (body['ok'] != true) {
      await _set(kOptionGoTechTeamOwner, '');
      await _set(kOptionGoTechTeamLabel, '');
    } else {
      await _set(kOptionGoTechTeamOwner, _str(body, 'ownerName'));
      await _set(kOptionGoTechTeamLabel, _str(body, 'label'));
      await _applySupport(body['support']);
      await _applyUpdate(body['update']);
    }
    GoTechRegistration.load();
  } catch (e) {
    // offline is fine: keep what we knew
    debugPrint('GoTech team check failed: $e');
  }
}

Future<bool> goTechHeartbeat() async {
  _currentVersion = await bind.mainGetVersion();
  GoTechUpdate.load();
  final token = _get(kOptionGoTechDeviceToken);
  if (token.isEmpty) {
    if (_get(kOptionGoTechCustomerCode).isNotEmpty) {
      await _clearRegistration();
      return false;
    }
    await _askIfTeamMachine();
    return true;
  }
  try {
    final (status, body) = await _post('/api/desk/heartbeat', {
      'deskId': await _deskId(),
      'deviceToken': token,
      'hostname': Platform.localHostname,
      'appVersion': await bind.mainGetVersion(),
    });
    if (status == _kHttpUnauthorized) {
      await _clearRegistration();
      return false;
    }
    if (status == _kHttpOk && body['ok'] == true) {
      await _set(kOptionGoTechCompanyName, _str(body, 'companyName'));
      await _set(kOptionGoTechPersonName, _str(body, 'personName'));
      await _set(kOptionGoTechLabel, _str(body, 'label'));
      if (_str(body, 'customerCode').isNotEmpty) {
        await _set(kOptionGoTechCustomerCode, _str(body, 'customerCode'));
      }
      await _applySupport(body['support']);
      await _applyUpdate(body['update']);
      GoTechRegistration.load();
    }
  } catch (e) {
    // offline is fine: keep the last known registration
    debugPrint('GoTech heartbeat failed: $e');
  }
  return true;
}

/// Stores the GoTech team's computers and, while the lock is on, lets only them connect.
Future<void> _applySupport(dynamic support) async {
  if (support is! Map) return;
  final ids = (support['ids'] is List ? support['ids'] as List : [])
      .map((id) => '$id'.replaceAll(' ', ''))
      .where((id) => id.isNotEmpty)
      .toList();
  await _set(kOptionGoTechSupportIds, ids.join(','));
  final names = support['names'];
  await _set(kOptionGoTechSupportNames, names is Map ? jsonEncode(names) : '');
  await applyGoTechLock();
}

/// Writes (or clears) RustDesk's id whitelist from the team list.
Future<void> applyGoTechLock() async {
  final locked = _get(kOptionGoTechLockToTeam) != 'N';
  final ids = _get(kOptionGoTechSupportIds);
  final current = bind.mainGetOptionSync(key: kOptionIdWhitelist);
  final wanted = locked ? ids : '';
  // only touch the option when we own its value, so a hand-written whitelist survives
  if (current == wanted || (current.isNotEmpty && !locked && current != ids)) return;
  await bind.mainSetOption(key: kOptionIdWhitelist, value: wanted);
}

Future<void> _applyUpdate(dynamic update) async {
  if (update is! Map) {
    await _set(kOptionGoTechLatestVersion, '');
    return;
  }
  final version = '${update['version'] ?? ''}';
  final url = Platform.isMacOS ? '${update['macUrl'] ?? ''}' : '${update['windowsUrl'] ?? ''}';
  await _set(kOptionGoTechLatestVersion, version);
  await _set(kOptionGoTechDownloadUrl, url);
}

Future<GoTechResult<int>> goTechSupportRequest(String message) async {
  try {
    final (status, body) = await _post('/api/desk/support-request', {
      'deskId': await _deskId(),
      'deviceToken': _get(kOptionGoTechDeviceToken),
      'message': message,
    });
    if (status == _kHttpOk && body['ok'] == true) {
      final number = body['ticketNumber'];
      return GoTechResult.ok(number is int ? number : 0);
    }
    if (status == _kHttpUnauthorized) await _clearRegistration();
    return GoTechResult.fail(_errorOf(body, status));
  } catch (e) {
    debugPrint('GoTech support request failed: $e');
    return const GoTechResult.fail(_kUnreachable);
  }
}
