part of 'gotech_api.dart';

// Signing in with the panel account instead of typing a company code: every person has their own
// e-mail, so the account already says which company, and whose, this computer is.

/// A panel account the app signed in with; [user] is the payload RustDesk keeps as its account info.
class GoTechAccount {
  final String token;
  final bool isStaff;
  final String name;
  final Map<String, dynamic> user;
  const GoTechAccount(this.token, this.isStaff, this.name, this.user);
}

/// Checks the e-mail and password with the panel, through the same /api/login RustDesk's account uses.
Future<GoTechResult<GoTechAccount>> goTechSignIn(
    String email, String password) async {
  try {
    final (status, body) =
        await _post('/api/login', {'username': email, 'password': password});
    final token = _str(body, 'access_token');
    final user = body['user'];
    if (status != _kHttpOk || token.isEmpty || user is! Map<String, dynamic>) {
      return GoTechResult.fail(_errorOf(body, status));
    }
    return GoTechResult.ok(GoTechAccount(
        token, user['is_admin'] == true, '${user['name'] ?? ''}', user));
  } catch (e) {
    debugPrint('GoTech sign-in failed: $e');
    return const GoTechResult.fail(_kUnreachable);
  }
}

/// Ends the panel session of a sign-in. Best effort: the app forgets the token either way.
Future<void> goTechSignOut(String token) async {
  try {
    await _post('/api/logout', {}, token: token);
  } catch (e) {
    debugPrint('GoTech sign-out failed: $e');
  }
}

/// Tells the panel whose computer this is by the signed-in account and keeps the answer: a customer's
/// computer is registered to their company as theirs, a team member's becomes a GoTech computer.
/// Returns an error message, or null on success.
Future<String?> goTechClaim(GoTechAccount account, {bool unattended = false}) =>
    account.isStaff ? _claimTeam(account) : _claimCustomer(account, unattended);

Future<Map<String, dynamic>> _claimPayload(String? unattendedPassword) async =>
    {
      'deskId': await _deskId(),
      'hostname': Platform.localHostname,
      'platform': Platform.operatingSystem,
      'appVersion': await bind.mainGetVersion(),
      'unattendedPassword': unattendedPassword,
    };

Future<String?> _claimTeam(GoTechAccount account) async {
  try {
    final (status, body) = await _post(
        '/api/desk/claim', await _claimPayload(null),
        token: account.token);
    if (status != _kHttpOk || body['ok'] != true) return _errorOf(body, status);
    // the panel refuses a computer registered to a customer, so any registration kept here is stale
    await _clearRegistration();
    await _set(kOptionGoTechTeamOwner, _str(body, 'ownerName'));
    await _set(kOptionGoTechTeamLabel, _str(body, 'label'));
    await _applySupport(body['support']);
    await _applyUpdate(body['update']);
    GoTechRegistration.load();
    return null;
  } catch (e) {
    debugPrint('GoTech team claim failed: $e');
    return _kUnreachable;
  }
}

Future<String?> _claimCustomer(GoTechAccount account, bool unattended) async {
  final wasUnattended = _get(kOptionGoTechUnattended) == 'Y';
  final password = unattended ? _generatePassword() : null;
  try {
    final (status, body) = await _post(
        '/api/desk/claim', await _claimPayload(password),
        token: account.token);
    if (status != _kHttpOk || body['ok'] != true) return _errorOf(body, status);
    // the panel replaced the device token, so the new one is kept whatever happens next
    await _set(kOptionGoTechCustomerCode, _str(body, 'customerCode'));
    await _set(kOptionGoTechCompanyName, _str(body, 'companyName'));
    await _set(kOptionGoTechPersonName, _str(body, 'personName'));
    await _set(kOptionGoTechLabel, _str(body, 'label'));
    await _set(kOptionGoTechDeviceToken, _str(body, 'deviceToken'));
    // The password changes only now that the panel holds the new one (or none). The app cannot read the old
    // one back, so changing it first and undoing on failure lost unattended access to a network error.
    var applied = true;
    if (password != null || wasUnattended) {
      applied = await bind.mainSetPermanentPasswordWithResult(
          password: password ?? '');
    }
    await _set(kOptionGoTechUnattended, unattended && applied ? 'Y' : '');
    // whatever this computer was before, it is a customer's now
    await _set(kOptionGoTechTeamOwner, '');
    await _set(kOptionGoTechTeamLabel, '');
    await _applySupport(body['support']);
    await _applyUpdate(body['update']);
    GoTechRegistration.load();
    return applied
        ? null
        : 'Kayıt tamam ama kalıcı şifre ayarlanamadı; gözetimsiz erişim çalışmaz.';
  } catch (e) {
    debugPrint('GoTech claim failed: $e');
    return _kUnreachable;
  }
}
