import 'package:http/http.dart' as http;

String? get recitationApiBaseUrl {
  const configured = String.fromEnvironment('RECITATION_API_URL');
  return configured.isEmpty ? null : configured.replaceFirst(RegExp(r'/$'), '');
}

Future<void> attachRecordedAudio(
  http.MultipartRequest request,
  String? audioPath,
) async {
  if (audioPath == null || audioPath.isEmpty) return;
  final response = await http.get(Uri.parse(audioPath));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('The browser recording could not be read.');
  }
  request.files.add(
    http.MultipartFile.fromBytes(
      'audio',
      response.bodyBytes,
      filename: 'recitation.webm',
    ),
  );
}
