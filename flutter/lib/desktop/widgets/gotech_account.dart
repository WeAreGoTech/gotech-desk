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
Future<String?> goTechClaim(GoTechAccount account,
    {bool unattended = false}) async {
  final err = account.isStaff
      ? await _claimTeam(account)
      : await _claimCustomer(account, unattended);
  // a warning can come with a registration that went through, so the state decides
  if (GoTechRegistration.isRegistered || GoTechRegistration.isTeamMachine) {
    await _set(kOptionGoTechEmail, '${account.user['email'] ?? ''}');
    GoTechRegistration.load();
  }
  return err;
}

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
    // the panel dropped whatever customer registration this computer had; the answer was the confirmation
    await _clearRegistration();
    // a password GoTech set for a customer's unattended access is no longer stored anywhere but here
    if (_get(kOptionGoTechUnattended) == 'Y') {
      await bind.mainSetPermanentPasswordWithResult(password: '');
      await _set(kOptionGoTechUnattended, '');
    }
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

/// A team member answered that this computer is not GoTech's: it leaves the team list (nothing happens when it was
/// not on it), so the customer registration that follows goes through. Returns an error message, or null.
Future<String?> goTechReleaseTeam(GoTechAccount account) async {
  try {
    final (status, body) = await _post(
        '/api/desk/release', {'deskId': await _deskId()},
        token: account.token);
    if (status != _kHttpOk || body['ok'] != true) return _errorOf(body, status);
    await _set(kOptionGoTechTeamOwner, '');
    await _set(kOptionGoTechTeamLabel, '');
    await _set(kOptionGoTechEmail, '');
    GoTechRegistration.load();
    return null;
  } catch (e) {
    debugPrint('GoTech team release failed: $e');
    return _kUnreachable;
  }
}

Future<String?> _claimCustomer(GoTechAccount account, bool unattended) async {
  final password = unattended ? _generatePassword() : null;
  try {
    final (status, body) = await _post(
        '/api/desk/claim', await _claimPayload(password),
        token: account.token);
    if (status != _kHttpOk || body['ok'] != true) return _errorOf(body, status);
    return _keepCustomerRegistration(body, password);
  } catch (e) {
    debugPrint('GoTech claim failed: $e');
    return _kUnreachable;
  }
}

/// A person's one-click setup link (the installer's name, or gotechdesk://kur/<token>): the computer is registered to
/// them with no password. A team member's link only gives back their e-mail to sign in with.
Future<({String? error, String? staffEmail})> goTechSetup(String token) async {
  try {
    final payload = await _claimPayload(null)
      ..remove('unattendedPassword')
      ..['token'] = token;
    final (status, body) = await _post('/api/desk/setup', payload);
    if (status != _kHttpOk || body['ok'] != true) {
      return (error: _errorOf(body, status), staffEmail: null);
    }
    if (body['kind'] == 'password') {
      return (error: null, staffEmail: _str(body, 'email'));
    }
    return (
      error: await _keepCustomerRegistration(body, null),
      staffEmail: null
    );
  } catch (e) {
    debugPrint('GoTech setup failed: $e');
    return (error: _kUnreachable, staffEmail: null);
  }
}

/// Keeps the customer registration the panel just made and switches the permanent password to the one it now holds
/// (or none). Returns a warning when that password could not be set.
Future<String?> _keepCustomerRegistration(
    Map<String, dynamic> body, String? password) async {
  final wasUnattended = _get(kOptionGoTechUnattended) == 'Y';
  // the panel replaced the device token, so the new one is kept whatever happens next
  await _set(kOptionGoTechCustomerCode, _str(body, 'customerCode'));
  await _set(kOptionGoTechCompanyName, _str(body, 'companyName'));
  await _set(kOptionGoTechPersonName, _str(body, 'personName'));
  await _set(kOptionGoTechLabel, _str(body, 'label'));
  await _set(kOptionGoTechDeviceToken, _str(body, 'deviceToken'));
  // a setup link names no account; goTechClaim sets the one that signed in
  await _set(kOptionGoTechEmail, '');
  // The password changes only now that the panel holds the new one (or none). The app cannot read the old
  // one back, so changing it first and undoing on failure lost unattended access to a network error.
  var applied = true;
  if (password != null || wasUnattended) {
    applied =
        await bind.mainSetPermanentPasswordWithResult(password: password ?? '');
  }
  await _set(kOptionGoTechUnattended, password != null && applied ? 'Y' : '');
  // whatever this computer was before, it is a customer's now
  await _set(kOptionGoTechTeamOwner, '');
  await _set(kOptionGoTechTeamLabel, '');
  await _applySupport(body['support']);
  await _applyUpdate(body['update']);
  GoTechRegistration.load();
  return applied
      ? null
      : 'Kayıt tamam ama kalıcı şifre ayarlanamadı; gözetimsiz erişim çalışmaz.';
}

/// "Çıkış yap": this computer stops being anyone's. A customer's registration is dropped on the panel too, and
/// a team computer leaves the team list, so nothing of the last person stays on it. Returns an error, or null.
Future<String?> goTechSignOutComputer() async {
  try {
    final deviceToken = _get(kOptionGoTechDeviceToken);
    if (deviceToken.isNotEmpty) {
      final (status, body) = await _post('/api/desk/signout',
          {'deskId': await _deskId(), 'deviceToken': deviceToken});
      // a 401 means the panel had already forgotten it
      if (status != _kHttpUnauthorized &&
          (status != _kHttpOk || body['ok'] != true)) {
        return _errorOf(body, status);
      }
    }
    final sessionToken = _get('access_token');
    if (GoTechRegistration.isTeamMachine && sessionToken.isNotEmpty) {
      final (status, body) = await _post(
          '/api/desk/release', {'deskId': await _deskId()},
          token: sessionToken);
      if (status != _kHttpOk || body['ok'] != true) {
        return _errorOf(body, status);
      }
    }
  } catch (e) {
    debugPrint('GoTech sign-out of the computer failed: $e');
    return _kUnreachable;
  }
  await _set(kOptionGoTechTeamOwner, '');
  await _set(kOptionGoTechTeamLabel, '');
  await _clearRegistration();
  return null;
}
