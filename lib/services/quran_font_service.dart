import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class QuranFontService {
  static const indoPakFamily = 'QuranIndoPakNastaleeq';
  static final indoPakFontUri = Uri.parse(
    'https://verses.quran.foundation/fonts/quran/hafs/nastaleeq/indopak/'
    'indopak-nastaleeq-waqf-lazim-v4.2.1.ttf',
  );

  static Future<bool>? _indoPakLoad;

  static Future<bool> ensureIndoPakLoaded({http.Client? client}) {
    final existing = _indoPakLoad;
    if (existing != null) return existing;

    final future = _loadIndoPak(client);
    _indoPakLoad = future;
    return future.then((loaded) {
      if (!loaded && identical(_indoPakLoad, future)) {
        _indoPakLoad = null;
      }
      return loaded;
    });
  }

  static Future<bool> _loadIndoPak(http.Client? suppliedClient) async {
    final client = suppliedClient ?? http.Client();
    try {
      final response = await client.get(indoPakFontUri);
      if (response.statusCode != 200 || response.bodyBytes.length < 1000) {
        return false;
      }

      final loader = FontLoader(indoPakFamily)
        ..addFont(
          Future<ByteData>.value(ByteData.sublistView(response.bodyBytes)),
        );
      await loader.load();
      return true;
    } catch (_) {
      return false;
    } finally {
      if (suppliedClient == null) client.close();
    }
  }
}
