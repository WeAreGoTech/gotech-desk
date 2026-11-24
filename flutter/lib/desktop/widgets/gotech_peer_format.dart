import 'package:flutter_hbb/common/formatter/id_formatter.dart';

// Text rules for the GoTech peer lists and the connect field: search matching, row titles and the
// "Son görülme" column. Pure Dart, so the widget tests can use it without the native bridge.

const _kTurkishFold = {
  'ı': 'i',
  'İ': 'i',
  'I': 'i',
  'ş': 's',
  'Ş': 's',
  'ğ': 'g',
  'Ğ': 'g',
  'ü': 'u',
  'Ü': 'u',
  'ö': 'o',
  'Ö': 'o',
  'ç': 'c',
  'Ç': 'c',
};
// "İ".toLowerCase() leaves a combining dot behind
const _kCombiningDot = '̇';
final _digitQuery = RegExp(r'^[\d\s]+$');
final _anyDigit = RegExp(r'\d');
final _spaces = RegExp(r'\s');

const kGoTechNoName = 'İsim girilmemiş';
const kGoTechNoValue = '—';
const kGoTechOnlineText = 'Çevrimiçi';
const kGoTechMinDirectIdLength = 6;
const kGoTechMaxPeerSuggestions = 6;
const kGoTechMaxCompanySuggestions = 4;

const _kMonths = [
  'Oca',
  'Şub',
  'Mar',
  'Nis',
  'May',
  'Haz',
  'Tem',
  'Ağu',
  'Eyl',
  'Eki',
  'Kas',
  'Ara',
];
const _kDaysAsRelative = 7;

/// Lower case with Turkish letters folded to ASCII, so "dilamed" finds "DİLAMED" and "sevimli" finds "SEVİMLİ".
String goTechNormalize(String text) {
  final out = StringBuffer();
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    if (ch == _kCombiningDot) continue;
    out.write(_kTurkishFold[ch] ?? ch.toLowerCase());
  }
  return out.toString();
}

/// Only digits and spaces, with at least one digit: the user is typing an ID.
bool goTechIsDigitQuery(String query) =>
    _digitQuery.hasMatch(query) && _anyDigit.hasMatch(query);

String goTechStripSpaces(String text) => text.replaceAll(_spaces, '');

/// The folded text a search looks in: alias, hostname, ID and company tags. Worth caching per peer.
String goTechHaystack({
  required String id,
  required String alias,
  required String hostname,
  required Iterable<String> tags,
}) =>
    goTechNormalize([alias, hostname, id, ...tags].join('\n'));

/// A search text prepared once, then matched against many peers: the one search rule of the GoTech lists
/// and the connect field. Digits also match the ID with its spaces ignored.
class GoTechQuery {
  final String text;
  final String normalized;
  final bool digits;

  /// [text] without spaces, for ID matching.
  final String typedId;

  GoTechQuery(String raw)
      : text = raw.trim(),
        normalized = goTechNormalize(raw.trim()),
        digits = goTechIsDigitQuery(raw.trim()),
        typedId = goTechStripSpaces(raw);

  bool get isEmpty => text.isEmpty;

  bool matches({required String id, required String haystack}) {
    if (isEmpty) return true;
    if (digits && goTechStripSpaces(id).contains(typedId)) return true;
    return haystack.contains(normalized);
  }
}

/// A peer as the GoTech views need it, free of the native models.
class GoTechPeerInfo {
  final String id;
  final String alias;
  final String hostname;
  final List<String> tags;
  final String platform;
  final bool online;

  /// We connected to it before: it is in the recent sessions.
  final bool recent;
  final DateTime? lastSeen;
  String? _haystack;

  GoTechPeerInfo({
    required this.id,
    this.alias = '',
    this.hostname = '',
    this.tags = const [],
    this.platform = '',
    this.online = false,
    this.recent = false,
    this.lastSeen,
    String? haystack,
  }) : _haystack = haystack;

  String get company => tags.isEmpty ? '' : tags.first;

  String get haystack => _haystack ??=
      goTechHaystack(id: id, alias: alias, hostname: hostname, tags: tags);

  bool matches(GoTechQuery query) => query.matches(id: id, haystack: haystack);
}

/// The panel puts the hostname in the alias when nobody is named; that counts as no name.
bool goTechHasName(String alias, String hostname) {
  final a = alias.trim();
  return a.isNotEmpty && goTechNormalize(a) != goTechNormalize(hostname.trim());
}

/// Bold first line of a row: the person, else the computer, else the ID.
String goTechPeerTitle(GoTechPeerInfo p) {
  if (goTechHasName(p.alias, p.hostname)) return p.alias.trim();
  if (p.hostname.trim().isNotEmpty) return p.hostname.trim();
  return formatID(p.id);
}

/// Second line: the hostname under a named person, otherwise a note that nobody is named.
String goTechPeerDetail(GoTechPeerInfo p) =>
    goTechHasName(p.alias, p.hostname) ? p.hostname.trim() : kGoTechNoName;

String _two(int n) => n.toString().padLeft(2, '0');

/// "Son görülme": "Az önce", "5 dk önce", "2 saat önce", "Dün 17:42", "4 gün önce", "12 Kas", "3 Mar 2025".
String goTechLastSeenText(DateTime? lastSeen, {required DateTime now}) {
  if (lastSeen == null) return kGoTechNoValue;
  final t = lastSeen.toLocal();
  final diff = now.difference(t);
  if (diff.isNegative || diff.inMinutes < 1) return 'Az önce';
  if (diff.inHours < 1) return '${diff.inMinutes} dk önce';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final days = today.difference(day).inDays;
  if (days == 0) return '${diff.inHours} saat önce';
  if (days == 1) return 'Dün ${_two(t.hour)}:${_two(t.minute)}';
  if (days < _kDaysAsRelative) return '$days gün önce';
  final date = '${t.day} ${_kMonths[t.month - 1]}';
  return t.year == now.year ? date : '$date ${t.year}';
}

enum GoTechConnectKind { direct, peer, company }

/// One line of the connect field's dropdown.
class GoTechConnectItem {
  final GoTechConnectKind kind;

  /// The typed ID for [GoTechConnectKind.direct].
  final String id;
  final GoTechPeerInfo? peer;
  final String company;
  final int companyCount;

  const GoTechConnectItem.direct(this.id)
      : kind = GoTechConnectKind.direct,
        peer = null,
        company = '',
        companyCount = 0;

  GoTechConnectItem.peer(GoTechPeerInfo this.peer)
      : kind = GoTechConnectKind.peer,
        id = peer.id,
        company = peer.company,
        companyCount = 0;

  const GoTechConnectItem.company(this.company, this.companyCount)
      : kind = GoTechConnectKind.company,
        id = '',
        peer = null;
}

int _rankPeers(GoTechPeerInfo a, GoTechPeerInfo b, String idPrefix,
    Map<GoTechPeerInfo, String> names) {
  int flag(bool v) => v ? 0 : 1;
  if (idPrefix.isNotEmpty) {
    final c = flag(goTechStripSpaces(a.id).startsWith(idPrefix))
        .compareTo(flag(goTechStripSpaces(b.id).startsWith(idPrefix)));
    if (c != 0) return c;
  }
  final recent = flag(a.recent).compareTo(flag(b.recent));
  if (recent != 0) return recent;
  final online = flag(a.online).compareTo(flag(b.online));
  if (online != 0) return online;
  return names[a]!.compareTo(names[b]!);
}

/// The connect field's dropdown: a direct-connect line for a typed ID nobody in the list has, then
/// matching computers (ID prefix, then earlier sessions, then online, then name), then matching companies.
List<GoTechConnectItem> goTechConnectItems(
  GoTechQuery query, {
  required List<GoTechPeerInfo> peers,
  required Map<String, int> companies,
}) {
  if (query.isEmpty) return const [];
  final hits = peers.where((p) => p.matches(query)).toList();
  final names = {for (final p in hits) p: goTechNormalize(goTechPeerTitle(p))};
  final idPrefix = query.digits ? query.typedId : '';
  hits.sort((a, b) => _rankPeers(a, b, idPrefix, names));
  final known = hits.any((p) => goTechStripSpaces(p.id) == query.typedId);
  return [
    // a known ID shows up as its computer, with the name, instead
    if (query.digits &&
        query.typedId.length >= kGoTechMinDirectIdLength &&
        !known)
      GoTechConnectItem.direct(query.typedId),
    ...hits.take(kGoTechMaxPeerSuggestions).map(GoTechConnectItem.peer),
    if (!query.digits)
      ...companies.entries
          .where((e) => goTechNormalize(e.key).contains(query.normalized))
          .take(kGoTechMaxCompanySuggestions)
          .map((e) => GoTechConnectItem.company(e.key, e.value)),
  ];
}
