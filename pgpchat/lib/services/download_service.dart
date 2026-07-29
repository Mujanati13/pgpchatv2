import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:pgpchat/services/pgp_service.dart';

class DownloadService {
  static const MethodChannel _androidChannel = MethodChannel(
    'com.pgpchat/download',
  );

  static Future<String?> downloadTextFile({
    required String fileName,
    required String content,
  }) async {
    if (Platform.isAndroid) {
      try {
        return await _androidChannel.invokeMethod<String>(
          'saveTextToDownloads',
          {
            'fileName': fileName,
            'content': content,
          },
        );
      } on PlatformException catch (e) {
        throw Exception(e.message ?? 'Could not download file');
      }
    }

    final bytes = Uint8List.fromList(utf8.encode(content));
    return FilePicker.platform.saveFile(
      dialogTitle: 'Save File',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: PgpService.supportedKeyFileExtensions,
      bytes: bytes,
    );
  }

  static Future<void> openDownloads() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _androidChannel.invokeMethod<bool>('openDownloads');
    } on PlatformException {
      // Best-effort helper for UX. Download already succeeded.
    }
  }
}
