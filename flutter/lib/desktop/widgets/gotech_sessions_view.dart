import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:get/get.dart';

import 'gotech_api.dart';
import 'gotech_home.dart';

const _kActivePollInterval = Duration(seconds: 2);
const _kClockTick = Duration(seconds: 1);
// the app posts the session's close to the panel a moment after it ends
const _kHistoryRefreshDelay = Duration(seconds: 3);
const _kHistoryRows = 5;
const _kMinutesPerHour = 60;
const _kMonths = [
  'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', //
  'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
];
const _kLiveGreen = Color(0xFF2E9E5B);

// bumped when an incoming session ends, so the history picks it up
final _sessionsEnded = 0.obs;

String _twoDigits(int n) => n.toString().padLeft(2, '0');

/// "Bugün 14:05", "Dün 09:30", "18 Eyl 21:56".
String _when(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final time = '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
  final days = today.difference(day).inDays;
  if (days == 0) return 'Bugün $time';
  if (days == 1) return 'Dün $time';
  return '${date.day} ${_kMonths[date.month - 1]} $time';
}

/// "45 sn", "12 dk", "1 sa 5 dk".
String _length(Duration d) {
  if (d.inMinutes < 1) return '${d.inSeconds} sn';
  if (d.inMinutes < _kMinutesPerHour) return '${d.inMinutes} dk';
  final rest = d.inMinutes % _kMinutesPerHour;
  return '${d.inHours} sa${rest > 0 ? ' $rest dk' : ''}';
}

/// While someone is connected: who, for how long, and the voice call, AnyDesk-style on the home screen.
class GoTechActiveSessionsCard extends StatefulWidget {
  const GoTechActiveSessionsCard({Key? key}) : super(key: key);

  @override
  State<GoTechActiveSessionsCard> createState() =>
      _GoTechActiveSessionsCardState();
}

class _GoTechActiveSessionsCardState extends State<GoTechActiveSessionsCard> {
  List<GoTechActiveSession> _sessions = [];
  Timer? _poll;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(_kActivePollInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final sessions = await goTechActiveSessions();
    if (!mounted) return;
    if (sessions.length < _sessions.length) {
      Future.delayed(_kHistoryRefreshDelay, () => _sessionsEnded.value++);
    }
    setState(() => _sessions = sessions);
    if (sessions.isEmpty) {
      _clock?.cancel();
      _clock = null;
    } else {
      _clock ??= Timer.periodic(_kClockTick, (_) => setState(() {}));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sessions.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: goTechCardDecoration(context).copyWith(
        border: Border.all(color: _kLiveGreen.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.circle, size: 10, color: _kLiveGreen),
            const SizedBox(width: 8),
            Text('Şu an bağlı',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kLiveGreen)),
          ]),
          for (final s in _sessions) _ActiveRow(session: s),
        ],
      ),
    );
  }
}

class _ActiveRow extends StatelessWidget {
  final GoTechActiveSession session;
  const _ActiveRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final faded =
        Theme.of(context).textTheme.titleLarge?.color?.withOpacity(0.65);
    final voiceSince = session.voiceCallSince;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(session.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            Text(formatDurationToTime(now.difference(session.since)),
                style: const TextStyle(
                    fontSize: 15, fontFeatures: [FontFeature.tabularFigures()])),
          ]),
          Text(kGoTechConnTypeLabels[session.connType] ?? '',
              style: TextStyle(fontSize: 12, color: faded)),
          if (voiceSince != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                const Icon(Icons.call, size: 15, color: _kLiveGreen),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('Sesli görüşme',
                      style: TextStyle(fontSize: 13, color: _kLiveGreen)),
                ),
                Text(formatDurationToTime(now.difference(voiceSince)),
                    style: const TextStyle(
                        fontSize: 13,
                        color: _kLiveGreen,
                        fontFeatures: [FontFeature.tabularFigures()])),
              ]),
            ),
        ],
      ),
    );
  }
}

/// The last support sessions on this computer, from the panel (the cached copy while offline).
class GoTechHistoryCard extends StatefulWidget {
  const GoTechHistoryCard({Key? key}) : super(key: key);

  @override
  State<GoTechHistoryCard> createState() => _GoTechHistoryCardState();
}

class _GoTechHistoryCardState extends State<GoTechHistoryCard> {
  List<GoTechPastSession> _history = goTechCachedHistory();
  Worker? _onEnded;

  @override
  void initState() {
    super.initState();
    _load();
    _onEnded = ever(_sessionsEnded, (_) => _load());
  }

  @override
  void dispose() {
    _onEnded?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final history = await goTechFetchHistory();
    if (history != null && mounted) setState(() => _history = history);
  }

  @override
  Widget build(BuildContext context) {
    final faded =
        Theme.of(context).textTheme.titleLarge?.color?.withOpacity(0.6);
    final rows = _history.take(_kHistoryRows).toList();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: goTechCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Son destek bağlantıları',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('Henüz bağlantı yok.',
                  style: TextStyle(fontSize: 12, color: faded)),
            ),
          for (final s in rows) _HistoryRow(session: s, faded: faded),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final GoTechPastSession session;
  final Color? faded;
  const _HistoryRow({required this.session, required this.faded});

  @override
  Widget build(BuildContext context) {
    final started = session.startedAt;
    final ended = session.endedAt;
    final details = [
      if (started != null) _when(started),
      if (started != null && ended != null) _length(ended.difference(started)),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Expanded(
          child: Text(
            [session.name, kGoTechConnTypeLabels[session.connType] ?? '']
                .where((s) => s.isNotEmpty)
                .join(' · '),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        Text(details, style: TextStyle(fontSize: 12, color: faded)),
      ]),
    );
  }
}
