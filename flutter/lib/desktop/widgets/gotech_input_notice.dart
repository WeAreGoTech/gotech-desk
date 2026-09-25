import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/widgets/dialog.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/common/shared_state.dart';
import 'package:get/get.dart';

import 'gotech_home.dart';

const _kNoticeMaxWidth = 640.0;
const _kNoticeBottom = 16.0;

/// Says on the remote screen why the mouse may not move, instead of leaving it to guesswork: the other side
/// turned mouse and keyboard off, or the app runs there without being installed, so Windows keeps input
/// away from any window started as administrator (Task Manager, an installer, a UAC prompt).
class GoTechInputNotice extends StatefulWidget {
  final String id;
  final FFI ffi;
  const GoTechInputNotice({Key? key, required this.id, required this.ffi})
      : super(key: key);

  @override
  State<GoTechInputNotice> createState() => _GoTechInputNoticeState();
}

class _GoTechInputNoticeState extends State<GoTechInputNotice> {
  String _dismissed = '';

  @override
  Widget build(BuildContext context) {
    final ffi = widget.ffi;
    if (ffi.connType != ConnType.defaultConn) return const Offstage();
    return ListenableBuilder(
      listenable: Listenable.merge([ffi.ffiModel, ffi.elevationModel]),
      builder: (context, _) => Obx(() {
        final String text;
        var canElevate = false;
        if (!KeyboardEnabledState.find(widget.id).value) {
          text = 'Karşı taraf fare ve klavye iznini kapattı; fareyi '
              'hareket ettiremezsiniz. Bağlantı penceresinde "Klavye/Fare" '
              'iznini açmasını isteyin.';
        } else if (ffi.elevationModel.showRequestMenu) {
          text = 'Karşı bilgisayarda GoTech Desk kurulu değil. Yönetici olarak '
              'açılan pencerelerde (Görev Yöneticisi, kurulum, UAC onayı) fare '
              've klavye çalışmaz. Yetki isteyin ya da uygulamayı kurdurun.';
          canElevate = true;
        } else {
          return const Offstage();
        }
        if (_dismissed == text) return const Offstage();
        return Positioned(
          left: 0,
          right: 0,
          bottom: _kNoticeBottom,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kNoticeMaxWidth),
              child: Material(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.mouse_outlined, color: kGoTechRed),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(text,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                      ),
                      if (canElevate)
                        TextButton(
                          onPressed: () => showRequestElevationDialog(
                              ffi.sessionId, ffi.dialogManager),
                          style:
                              TextButton.styleFrom(foregroundColor: kGoTechRed),
                          child: const Text('Yetki iste'),
                        ),
                      IconButton(
                        tooltip: 'Kapat',
                        onPressed: () => setState(() => _dismissed = text),
                        icon: const Icon(Icons.close,
                            color: Colors.white70, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
