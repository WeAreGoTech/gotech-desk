import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';

// The system default output; stored as an empty device name.
const _kDefaultOutput = 'Default';

/// The microphone switch of a running voice call. The capture lives in the connection manager's
/// service on the controlled side ([isCm]) and in this process on the controlling side.
class VoiceCallMute extends StatefulWidget {
  final bool isCm;
  final Widget Function(bool muted, VoidCallback toggle) builder;

  const VoiceCallMute({Key? key, required this.isCm, required this.builder})
      : super(key: key);

  @override
  State<VoiceCallMute> createState() => _VoiceCallMuteState();
}

class _VoiceCallMuteState extends State<VoiceCallMute> {
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    bind.getVoiceCallMuted(isCm: widget.isCm).then((muted) {
      if (mounted) setState(() => _muted = muted);
    });
  }

  Future<void> _toggle() async {
    final muted = !_muted;
    await bind.setVoiceCallMuted(isCm: widget.isCm, muted: muted);
    if (mounted) setState(() => _muted = muted);
  }

  @override
  Widget build(BuildContext context) => widget.builder(_muted, _toggle);
}

/// The speaker the call (and the session's sound) plays on.
class AudioOutput {
  static String get defaultDevice => translate(_kDefaultOutput);

  /// Output devices with the system default first, and the one in use; empty where it cannot be chosen.
  static Future<Map<String, Object>> getDevicesInfo(bool isCm) async {
    final outputs = await bind.mainGetSoundOutputs();
    if (outputs.isEmpty) return {'devices': <String>[], 'current': ''};
    final devices = [defaultDevice, ...outputs];
    final current = await bind.getAudioOutputDevice(isCm: isCm);
    return {
      'devices': devices,
      'current': outputs.contains(current) ? current : defaultDevice,
    };
  }

  static Future<void> setDevice(String device, bool isCm) =>
      bind.setAudioOutputDevice(
          isCm: isCm, device: device == defaultDevice ? '' : device);
}
