part of 'gotech_api.dart';

// The last connection history fetched from the panel, shown while offline.
const kOptionGoTechSessionHistory = 'gotech-session-history';

/// RustDesk's connection types, as the server audits them.
const kGoTechConnTypeLabels = {
  0: 'Uzak masaüstü',
  1: 'Dosya aktarımı',
  2: 'Port yönlendirme',
  3: 'Kamera',
  4: 'Terminal',
};

/// Someone connected to this computer right now.
class GoTechActiveSession {
  final String peerId;
  final String name;
  final int connType;
  final DateTime since;
  final DateTime? voiceCallSince;

  const GoTechActiveSession(
      this.peerId, this.name, this.connType, this.since, this.voiceCallSince);

  /// The team member's name when it is one of ours, else what the peer's app calls itself.
  String get displayName =>
      goTechSupportName(peerId) ?? (name.isNotEmpty ? name : peerId);
}

/// A finished or running session from the panel's history.
class GoTechPastSession {
  final String name;
  final int? connType;
  final DateTime? startedAt;
  final DateTime? endedAt;

  const GoTechPastSession(this.name, this.connType, this.startedAt, this.endedAt);

  static GoTechPastSession? fromJson(dynamic json) {
    if (json is! Map) return null;
    DateTime? date(String key) =>
        json[key] is String ? DateTime.tryParse(json[key])?.toLocal() : null;
    return GoTechPastSession('${json['name'] ?? ''}',
        json['connType'] is int ? json['connType'] : null,
        date('startedAt'), date('endedAt'));
  }
}

DateTime? _fromMs(dynamic ms) =>
    ms is int ? DateTime.fromMillisecondsSinceEpoch(ms) : null;

/// The incoming sessions the process serving connections knows about; empty when it cannot be reached.
Future<List<GoTechActiveSession>> goTechActiveSessions() async {
  try {
    final list = jsonDecode(await bind.mainGetIncomingSessions());
    if (list is! List) return [];
    return list.whereType<Map>().map((s) {
      return GoTechActiveSession(
        '${s['peer_id'] ?? ''}',
        '${s['name'] ?? ''}',
        s['conn_type'] is int ? s['conn_type'] : 0,
        _fromMs(s['since_ms']) ?? DateTime.now(),
        _fromMs(s['voice_call_since_ms']),
      );
    }).toList();
  } catch (e) {
    debugPrint('GoTech active sessions failed: $e');
    return [];
  }
}

List<GoTechPastSession> _parseHistory(dynamic list) => (list is List ? list : [])
    .map(GoTechPastSession.fromJson)
    .whereType<GoTechPastSession>()
    .toList();

/// The history cached from the last successful fetch.
List<GoTechPastSession> goTechCachedHistory() {
  final raw = _get(kOptionGoTechSessionHistory);
  if (raw.isEmpty) return [];
  try {
    return _parseHistory(jsonDecode(raw));
  } catch (_) {
    return [];
  }
}

/// This computer's connection history from the panel; null when it could not be fetched.
Future<List<GoTechPastSession>?> goTechFetchHistory() async {
  final token = _get(kOptionGoTechDeviceToken);
  if (token.isEmpty) return null;
  try {
    final (status, body) = await _post('/api/desk/sessions', {
      'deskId': await _deskId(),
      'deviceToken': token,
    });
    if (status != _kHttpOk || body['ok'] != true) return null;
    await _set(kOptionGoTechSessionHistory, jsonEncode(body['sessions']));
    return _parseHistory(body['sessions']);
  } catch (e) {
    debugPrint('GoTech session history failed: $e');
    return null;
  }
}
