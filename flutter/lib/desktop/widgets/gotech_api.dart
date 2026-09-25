import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/utils/http_service.dart' as http;
import 'package:get/get.dart';

part 'gotech_account.dart';
part 'gotech_sessions.dart';

// Temporary sslip.io address until GoTech has a domain. SN404 (31.40.199.183).
const kGoTechApiBase = 'https://gotech-web-31-40-199-183.sslip.io';

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
// the e-mail of the account that signed this computer in, shown in the account menu
const kOptionGoTechEmail = 'gotech-email';
const _kOptionPresetToken = 'gotech-preset-token';
const _kOptionInstallOffered = 'gotech-install-offered';
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
// closing the window only hides it, so the app keeps running and can keep the team list fresh
const _kHeartbeatInterval = Duration(minutes: 5);
const _kHttpOk = 200;
const _kHttpUnauthorized = 401;
const _kUnreachable =
    'GoTech sunucusuna ulaşılamadı. İnternet bağlantınızı kontrol edin.';

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

/// Everyone but a GoTech team computer gets the simple screen: a customer, or a computer nobody signed in
/// on yet, only ever asks for help. The peer lists and the connect bar are for the team.
bool get goTechShowsSimpleHome =>
    !GoTechRegistration.isTeamMachine && _get('gotech-full-ui') != 'Y';

/// Registration state shown on the home page.
class GoTechRegistration {
  static final customerCode = ''.obs;
  static final companyName = ''.obs;
  static final personName = ''.obs;
  static final label = ''.obs;
  static final teamOwner = ''.obs;
  static final teamLabel = ''.obs;
  static final email = ''.obs;

  static void load() {
    customerCode.value = _get(kOptionGoTechCustomerCode);
    companyName.value = _get(kOptionGoTechCompanyName);
    personName.value = _get(kOptionGoTechPersonName);
    label.value = _get(kOptionGoTechLabel);
    teamOwner.value = _get(kOptionGoTechTeamOwner);
    teamLabel.value = _get(kOptionGoTechTeamLabel);
    email.value = _get(kOptionGoTechEmail);
  }

  /// A GoTech computer: not a customer, known to the panel by the desk ID a team member added.
  static bool get isTeamMachine => !isRegistered && teamOwner.value.isNotEmpty;

  static bool get isRegistered =>
      customerCode.value.isNotEmpty &&
      _get(kOptionGoTechDeviceToken).isNotEmpty;

  static bool get shouldPrompt =>
      !isRegistered &&
      !isTeamMachine &&
      _get(kOptionGoTechRegisterSkipped) != 'Y';

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

/// Posts JSON, with a panel session [token] when given, and returns (statusCode, decoded body map).
Future<(int, Map<String, dynamic>)> _post(
    String path, Map<String, dynamic> payload,
    {String? token}) async {
  final resp = await http
      .post(
        Uri.parse('${goTechApiBase()}$path'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
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

Future<void> _clearRegistration() async {
  // the unattended password was GoTech's; a computer signed out (here or from the panel) must not keep it
  if (_get(kOptionGoTechUnattended) == 'Y') {
    await bind.mainSetPermanentPasswordWithResult(password: '');
    await _set(kOptionGoTechUnattended, '');
  }
  for (final key in [
    kOptionGoTechCustomerCode,
    kOptionGoTechCompanyName,
    kOptionGoTechPersonName,
    kOptionGoTechLabel,
    kOptionGoTechDeviceToken,
    kOptionGoTechRegisterSkipped,
    kOptionGoTechEmail,
  ]) {
    await _set(key, '');
  }
  GoTechRegistration.load();
}

/// Refreshes what the panel knows about this device and what we show.
/// Returns false when the panel no longer knows this device.
/// The name of the file the person downloaded. The Windows exe is a packer that unpacks the app elsewhere
/// and runs it with the original name in RUSTDESK_APPNAME (libs/portable), so the app's own name says nothing.
String _downloadedFileName() {
  final packed = Platform.environment['RUSTDESK_APPNAME'] ?? '';
  return packed.isNotEmpty
      ? packed
      : File(Platform.resolvedExecutable).uri.pathSegments.last;
}

/// The token of a person's setup link, carried in the installer's name: GoTechDesk-kur-<token>.exe, or kept
/// for the installed copy by [goTechInstallDownload].
String goTechPresetSetupToken() =>
    RegExp(r'kur-([A-Za-z0-9_-]{20,100})')
        .firstMatch(_downloadedFileName())
        ?.group(1) ??
    _get(_kOptionPresetToken);

/// A setup link is spent once tried; the installed copy must not try it again at every start.
Future<void> goTechForgetPresetToken() => _set(_kOptionPresetToken, '');

/// The downloaded exe installs itself at its first start; only one named "...-portable.exe" (a separate
/// download on the panel) keeps running without installing. On a computer with an older version installed it
/// installs over it: running next to that version's service instead is what broke input and the ID.
/// Offered once per downloaded version: someone without admin rights who cancels or picks "Run without
/// install" gets the app as before. True when the installer took over.
Future<bool> goTechInstallDownload() async {
  // only the downloaded exe runs through the portable packer; the installed app never does
  final downloaded =
      (Platform.environment['RUSTDESK_APPNAME'] ?? '').isNotEmpty;
  final offerKey = '${_downloadedFileName()} ${await bind.mainGetVersion()}';
  if (!Platform.isWindows ||
      !downloaded ||
      bind.isDisableInstallation() ||
      (bind.mainIsInstalled() && !bind.mainIsInstalledLowerVersion()) ||
      _get(_kOptionInstallOffered) == offerKey ||
      _downloadedFileName().toLowerCase().contains('portable')) {
    return false;
  }
  // the installed copy is named GoTechDesk.exe and cannot read the setup link this file's name carried
  await _set(_kOptionPresetToken, goTechPresetSetupToken());
  await _set(_kOptionInstallOffered, offerKey);
  bind.mainGotoInstall();
  return true;
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
      // lets the panel trust the connection audit RustDesk posts, which carries only the ID and this
      'deviceUuid': await bind.mainGetUuid(),
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

Timer? _heartbeatTimer;

/// Repeats the heartbeat while the app runs, so a computer the team adds gets through a customer's lock,
/// and a panel edit shows up, without restarting the app.
void goTechStartHeartbeat() {
  _heartbeatTimer ??=
      Timer.periodic(_kHeartbeatInterval, (_) => goTechHeartbeat());
}

/// Stores the GoTech team's computers and, while the lock is on, lets only them connect.
Future<void> _applySupport(dynamic support) async {
  if (support is! Map) return;
  final ids = (support['ids'] is List ? support['ids'] as List : [])
      .map((id) => '$id'.replaceAll(' ', ''))
      .where((id) => id.isNotEmpty)
      .toList();
  // a whitelist written from the old list is still ours to replace
  final previousIds = _get(kOptionGoTechSupportIds);
  await _set(kOptionGoTechSupportIds, ids.join(','));
  final names = support['names'];
  await _set(kOptionGoTechSupportNames, names is Map ? jsonEncode(names) : '');
  await applyGoTechLock(previousIds: previousIds);
}

/// Writes (or clears) RustDesk's id whitelist from the team list.
Future<void> applyGoTechLock({String? previousIds}) async {
  // A team computer is not locked to the team: a teammate missing from its list, or added after it was
  // fetched, got "ID blocked", which is what kept the team from connecting to each other.
  final team = _get(kOptionGoTechDeviceToken).isEmpty &&
      _get(kOptionGoTechTeamOwner).isNotEmpty;
  final locked = !team && _get(kOptionGoTechLockToTeam) != 'N';
  final ids = _get(kOptionGoTechSupportIds);
  final current = bind.mainGetOptionSync(key: kOptionIdWhitelist);
  final wanted = locked ? ids : '';
  // only touch the option when we own its value, so a hand-written whitelist survives
  final ours = current.isEmpty || current == ids || current == previousIds;
  if (current == wanted || (!locked && !ours)) return;
  await bind.mainSetOption(key: kOptionIdWhitelist, value: wanted);
}

Future<void> _applyUpdate(dynamic update) async {
  if (update is! Map) {
    await _set(kOptionGoTechLatestVersion, '');
    return;
  }
  final version = '${update['version'] ?? ''}';
  final url = Platform.isMacOS
      ? '${update['macUrl'] ?? ''}'
      : '${update['windowsUrl'] ?? ''}';
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
