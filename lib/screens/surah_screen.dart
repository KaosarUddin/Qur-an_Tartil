import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/quran_models.dart';
import '../services/quran_font_service.dart';
import '../services/quran_script_service.dart';
import '../widgets/tajweed_text.dart';
import 'recitation_screen.dart';

enum _ReadingMode { uthmani, tajweed, indoPak }

class SurahScreen extends StatefulWidget {
  final Surah surah;

  const SurahScreen({super.key, required this.surah});

  @override
  State<SurahScreen> createState() => _SurahScreenState();
}

class _SurahScreenState extends State<SurahScreen> {
  late QuranScriptService _tajweedService;
  late QuranScriptService _indoPakService;
  late Future<Map<int, String>> _tajweed;
  Future<Map<int, String>>? _indoPak;
  _ReadingMode _mode = _ReadingMode.tajweed;
  bool _indoPakFontLoading = false;
  bool _indoPakFontLoaded = false;
  bool _indoPakFontFailed = false;

  @override
  void initState() {
    super.initState();
    _tajweedService = QuranScriptService();
    _indoPakService = QuranScriptService();
    _tajweed = _load(
      service: _tajweedService,
      script: QuranOnlineScript.tajweed,
    );
  }

  Future<Map<int, String>> _load({
    required QuranScriptService service,
    required QuranOnlineScript script,
  }) =>
      service.loadSurah(
        script: script,
        surah: widget.surah.number,
        expectedAyahCount: widget.surah.ayahs.length,
      );

  Future<Map<int, String>>? get _selectedFuture => switch (_mode) {
        _ReadingMode.uthmani => null,
        _ReadingMode.tajweed => _tajweed,
        _ReadingMode.indoPak => _indoPak,
      };

  void _selectMode(_ReadingMode mode) {
    if (mode == _ReadingMode.indoPak && _indoPak == null) {
      _indoPak = _load(
        service: _indoPakService,
        script: QuranOnlineScript.indoPak,
      );
      _loadIndoPakFont();
    }
    setState(() => _mode = mode);
  }

  Future<void> _loadIndoPakFont() async {
    if (_indoPakFontLoading || _indoPakFontLoaded) return;
    setState(() {
      _indoPakFontLoading = true;
      _indoPakFontFailed = false;
    });
    final loaded = await QuranFontService.ensureIndoPakLoaded();
    if (!mounted) return;
    setState(() {
      _indoPakFontLoading = false;
      _indoPakFontLoaded = loaded;
      _indoPakFontFailed = !loaded;
    });
  }

  void _retrySelectedMode() {
    var retryIndoPakFont = false;
    setState(() {
      if (_mode == _ReadingMode.tajweed) {
        _tajweedService.dispose();
        _tajweedService = QuranScriptService();
        _tajweed = _load(
          service: _tajweedService,
          script: QuranOnlineScript.tajweed,
        );
      } else if (_mode == _ReadingMode.indoPak) {
        _indoPakService.dispose();
        _indoPakService = QuranScriptService();
        _indoPak = _load(
          service: _indoPakService,
          script: QuranOnlineScript.indoPak,
        );
        retryIndoPakFont = true;
      }
    });
    if (retryIndoPakFont) _loadIndoPakFont();
  }

  Future<void> _openSource() async {
    if (!await launchUrl(QuranScriptService.sourceHomepage)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open quran.foundation.')),
      );
    }
  }

  @override
  void dispose() {
    _tajweedService.dispose();
    _indoPakService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.surah.nameEnglish} • ${widget.surah.nameArabic}'),
      ),
      body: FutureBuilder<Map<int, String>>(
        key: ValueKey(_mode),
        future: _selectedFuture,
        builder: (context, snapshot) {
          final onlineMode = _mode != _ReadingMode.uthmani;
          return Column(
            children: [
              _ReaderControls(
                mode: _mode,
                loading: onlineMode &&
                    (snapshot.connectionState != ConnectionState.done ||
                        (_mode == _ReadingMode.indoPak && _indoPakFontLoading)),
                failed: onlineMode && snapshot.hasError,
                indoPakFontFailed:
                    _mode == _ReadingMode.indoPak && _indoPakFontFailed,
                onChanged: _selectMode,
                onRetry: _retrySelectedMode,
                onOpenSource: _openSource,
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  itemCount: widget.surah.ayahs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final ayah = widget.surah.ayahs[index];
                    return _AyahCard(
                      surah: widget.surah,
                      ayah: ayah,
                      mode: _mode,
                      indoPakFontLoaded: _indoPakFontLoaded,
                      onlineText: onlineMode && snapshot.data != null
                          ? snapshot.data![ayah.number]
                          : null,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReaderControls extends StatelessWidget {
  final _ReadingMode mode;
  final bool loading;
  final bool failed;
  final bool indoPakFontFailed;
  final ValueChanged<_ReadingMode> onChanged;
  final VoidCallback onRetry;
  final VoidCallback onOpenSource;

  const _ReaderControls({
    required this.mode,
    required this.loading,
    required this.failed,
    required this.indoPakFontFailed,
    required this.onChanged,
    required this.onRetry,
    required this.onOpenSource,
  });

  String get _statusText {
    if (mode == _ReadingMode.uthmani) {
      return 'Bundled Uthmani text • available offline';
    }
    if (failed) {
      return 'Internet unavailable—showing offline Uthmani text';
    }
    if (loading) {
      return mode == _ReadingMode.tajweed
          ? 'Loading verified Tajweed annotations…'
          : 'Loading verified Indo-Pak script…';
    }
    if (mode == _ReadingMode.indoPak && indoPakFontFailed) {
      return 'Indo-Pak text loaded; using a fallback font';
    }
    return mode == _ReadingMode.tajweed
        ? 'Colours mark pronunciation rules; schemes vary by Mushaf.'
        : 'Indo-Pak Quranic orthography';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onlineMode = mode != _ReadingMode.uthmani;
    return Material(
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.menu_book_rounded),
                SizedBox(width: 8),
                Text(
                  'Quran script',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<_ReadingMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _ReadingMode.uthmani,
                    label: Text('Uthmani'),
                  ),
                  ButtonSegment(
                    value: _ReadingMode.tajweed,
                    label: Text('Tajweed colours'),
                  ),
                  ButtonSegment(
                    value: _ReadingMode.indoPak,
                    label: Text('Indo-Pak'),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (selection) => onChanged(selection.first),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _statusText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            if (mode == _ReadingMode.tajweed && !failed) ...[
              const SizedBox(height: 8),
              const TajweedLegend(),
            ],
            if (onlineMode && (failed || indoPakFontFailed))
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    failed
                        ? 'Retry selected script'
                        : 'Retry Indo-Pak typeface',
                  ),
                ),
              ),
            if (onlineMode)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onOpenSource,
                  child: const Text('Quran data provided by Quran Foundation'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AyahCard extends StatelessWidget {
  final Surah surah;
  final Ayah ayah;
  final _ReadingMode mode;
  final bool indoPakFontLoaded;
  final String? onlineText;

  const _AyahCard({
    required this.surah,
    required this.ayah,
    required this.mode,
    required this.indoPakFontLoaded,
    required this.onlineText,
  });

  @override
  Widget build(BuildContext context) {
    final indoPak = mode == _ReadingMode.indoPak;
    final arabicStyle = TextStyle(
      fontFamily:
          indoPak && indoPakFontLoaded ? QuranFontService.indoPakFamily : null,
      fontSize: indoPak ? 32 : 30,
      height: indoPak ? 2.4 : 2,
      fontWeight: FontWeight.w500,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 16, child: Text('${ayah.number}')),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  tooltip: 'Listen',
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Open Practice to hear the reference recitation.',
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.mic_rounded),
                  tooltip: 'Practice',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecitationScreen(
                        surah: surah,
                        ayah: ayah,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (mode == _ReadingMode.tajweed && onlineText != null)
              TajweedText(markup: onlineText!, style: arabicStyle)
            else
              Text(
                onlineText ?? ayah.arabic,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: arabicStyle,
              ),
            const SizedBox(height: 8),
            if (ayah.translation.isNotEmpty)
              Text(
                ayah.translation,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
