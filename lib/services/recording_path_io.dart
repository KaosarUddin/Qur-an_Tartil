import 'package:path_provider/path_provider.dart';

Future<String> createRecordingPath() async {
  final directory = await getTemporaryDirectory();
  return '${directory.path}/recitation_${DateTime.now().millisecondsSinceEpoch}.m4a';
}
