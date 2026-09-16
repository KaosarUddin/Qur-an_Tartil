import 'dart:io';

import 'package:http/http.dart' as http;

String get recitationApiBaseUrl {
  const configured = String.fromEnvironment('RECITATION_API_URL');
  if (configured.isNotEmpty) {
    return configured.replaceFirst(RegExp(r'/$'), '');
  }
  return Platform.isAndroid ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000';
}

Future<void> attachRecordedAudio(
  http.MultipartRequest request,
  String? audioPath,
) async {
  if (audioPath == null || !await File(audioPath).exists()) return;
  request.files.add(await http.MultipartFile.fromPath('audio', audioPath));
}
