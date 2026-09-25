import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/widgets/update_progress.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'gotech_api.dart';

// the only downloads RustDesk's updater accepts besides its own (src/updater.rs)
const _kReleaseAssetPrefix =
    'https://github.com/WeAreGoTech/gotech-desk/releases/download/';

/// An installed Windows app updates itself in place: it downloads the new exe and runs it with "--update",
/// RustDesk's own update path. A portable one, or a download from anywhere else, still opens the browser.
bool get goTechCanUpdateInPlace =>
    Platform.isWindows &&
    bind.mainIsInstalled() &&
    GoTechUpdate.url.value.startsWith(_kReleaseAssetPrefix) &&
    GoTechUpdate.url.value.endsWith('.exe');

void goTechStartUpdate() {
  final url = GoTechUpdate.url.value;
  if (!goTechCanUpdateInPlace) {
    launchUrl(Uri.parse(url));
    return;
  }
  // .../releases/download/<tag>/<file> -> .../releases/tag/<tag>, where the error dialog's "Download" leads
  final releasePage = url
      .substring(0, url.lastIndexOf('/'))
      .replaceFirst('/releases/download/', '/releases/tag/');
  final downloadId = SimpleWrapper('');
  final onCanceled = SimpleWrapper<VoidCallback>(() {});
  gFFI.dialogManager.dismissAll();
  gFFI.dialogManager.show((setState, close, context) {
    return CustomAlertDialog(
      title: Text('GoTech Desk ${GoTechUpdate.version.value} indiriliyor'),
      content: UpdateProgress(releasePage, url, downloadId, onCanceled)
          .marginSymmetric(horizontal: 8)
          .paddingOnly(top: 12),
      actions: [
        dialogButton('Vazgeç', onPressed: () async {
          onCanceled.value();
          await bind.mainSetCommon(
              key: 'cancel-downloader', value: downloadId.value);
          close();
        }, isOutline: true),
      ],
    );
  });
}
