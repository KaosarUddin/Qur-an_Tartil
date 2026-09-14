import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/quran_models.dart';
import '../services/quran_font_service.dart';
import '../services/quran_script_service.dart';
import '../widgets/tajweed_text.dart';
import 'recitation_screen.dart';

enum _ReadingMode { uthmani, tajweed, indoPak }

class _ReaderData {
  final Map<int, String> textByAyah;
  final Map<int, String>? tajweedByAyah;
  final String? basmala;
  final String? tajweedBasmala;

  const _ReaderData({
    required this.textByAyah,
    this.tajweedByAyah,
    this.basmala,
    this.tajweedBasmala,
  });
}

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
  late Future<_ReaderData> _tajweedReader;
  Future<Map<int, String>>? _indoPak;
  Future<_ReaderData>? _indoPakReader;
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
    _tajweedReader = _asTajweedReader(_tajweed);
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

  Future<_ReaderData> _asTajweedReader(Future<Map<int, String>> future) async {
    final text = await future;
    final basmala = widget.surah.basmala == null
        ? null
        : await _tajweedService.loadBasmala(QuranOnlineScript.tajweed);
    return _ReaderData(
      textByAyah: text,
      tajweedByAyah: text,
      basmala: basmala,
      tajweedBasmala: basmala,
    );
  }

  Future<_ReaderData> _asIndoPakReader(
    Future<Map<int, String>> indoPak,
    Future<Map<int, String>> tajweed,
  ) async {
    final text = await indoPak;
    final basmala = widget.surah.basmala == null
        ? null
        : await _indoPakService.loadBasmala(QuranOnlineScript.indoPak);
    Map<int, String>? tajweedText;
    String? tajweedBasmala;
    try {
      tajweedText = await tajweed;
      tajweedBasmala = widget.surah.basmala == null
          ? null
          : await _tajweedService.loadBasmala(QuranOnlineScript.tajweed);
    } catch (_) {
      tajweedText = null;
      tajweedBasmala = null;
    }
    return _ReaderData(
      textByAyah: text,
      tajweedByAyah: tajweedText,
      basmala: basmala,
      tajweedBasmala: tajweedBasmala,
    );
  }

  Future<_ReaderData>? get _selectedFuture => switch (_mode) {
        _ReadingMode.uthmani => null,
        _ReadingMode.tajweed => _tajweedReader,
        _ReadingMode.indoPak => _indoPakReader,
      };

  void _selectMode(_ReadingMode mode) {
    if (mode == _ReadingMode.indoPak && _indoPak == null) {
      _indoPak = _load(
        service: _indoPakService,
        script: QuranOnlineScript.indoPak,
      );
      _indoPakReader = _asIndoPakReader(_indoPak!, _tajweed);
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
        _tajweedReader = _asTajweedReader(_tajweed);
        if (_indoPak != null) {
          _indoPakReader = _asIndoPakReader(_indoPak!, _tajweed);
        }
      } else if (_mode == _ReadingMode.indoPak) {
        _tajweedService.dispose();
        _tajweedService = QuranScriptService();
        _tajweed = _load(
          service: _tajweedService,
          script: QuranOnlineScript.tajweed,
        );
        _tajweedReader = _asTajweedReader(_tajweed);
        _indoPakService.dispose();
        _indoPakService = QuranScriptService();
        _indoPak = _load(
          service: _indoPakService,
          script: QuranOnlineScript.indoPak,
        );
        _indoPakReader = _asIndoPakReader(_indoPak!, _tajweed);
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
      body: FutureBuilder<_ReaderData>(
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
                indoPakTajweedMissing: _mode == _ReadingMode.indoPak &&
                    snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData &&
                    snapshot.data!.tajweedByAyah == null,
                onChanged: _selectMode,
                onRetry: _retrySelectedMode,
                onOpenSource: _openSource,
              ),
              if (widget.surah.basmala != null)
                _BasmalaHeader(
                  mode: _mode,
                  offlineText: widget.surah.basmala!,
                  onlineText: onlineMode ? snapshot.data?.basmala : null,
                  tajweedMarkup:
                      onlineMode ? snapshot.data?.tajweedBasmala : null,
                  indoPakFontLoaded: _indoPakFontLoaded,
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
                          ? snapshot.data!.textByAyah[ayah.number]
                          : null,
                      tajweedMarkup:
                          onlineMode && snapshot.data?.tajweedByAyah != null
                              ? snapshot.data!.tajweedByAyah![ayah.number]
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
  final bool indoPakTajweedMissing;
  final ValueChanged<_ReadingMode> onChanged;
  final VoidCallback onRetry;
  final VoidCallback onOpenSource;

  const _ReaderControls({
    required this.mode,
    required this.loading,
    required this.failed,
    required this.indoPakFontFailed,
    required this.indoPakTajweedMissing,
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
    if (mode == _ReadingMode.indoPak && indoPakTajweedMissing) {
      return 'Indo-Pak loaded; Tajweed colours need a connection';
    }
    return mode == _ReadingMode.tajweed
        ? 'Colours mark pronunciation rules; schemes vary by Mushaf.'
        : 'Indo-Pak Nastaleeq with aligned Tajweed colours';
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
                    label: Text('Indo-Pak + Tajweed'),
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
            if (mode != _ReadingMode.uthmani &&
                !failed &&
                !indoPakTajweedMissing) ...[
              const SizedBox(height: 8),
              const TajweedLegend(),
            ],
            if (onlineMode &&
                (failed || indoPakFontFailed || indoPakTajweedMissing))
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    failed
                        ? 'Retry selected script'
                        : indoPakTajweedMissing
                            ? 'Retry Tajweed colours'
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
  final String? tajweedMarkup;

  const _AyahCard({
    required this.surah,
    required this.ayah,
    required this.mode,
    required this.indoPakFontLoaded,
    required this.onlineText,
    required this.tajweedMarkup,
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
                        displayText:
                            mode == _ReadingMode.indoPak ? onlineText : null,
                        tajweedMarkup: tajweedMarkup,
                        useIndoPakFont:
                            mode == _ReadingMode.indoPak && indoPakFontLoaded,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (mode == _ReadingMode.tajweed && onlineText != null)
              TajweedText(markup: onlineText!, style: arabicStyle)
            else if (mode == _ReadingMode.indoPak &&
                onlineText != null &&
                tajweedMarkup != null)
              TajweedText(
                markup: tajweedMarkup!,
                displayText: onlineText,
                style: arabicStyle,
              )
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

class _BasmalaHeader extends StatelessWidget {
  final _ReadingMode mode;
  final String offlineText;
  final String? onlineText;
  final String? tajweedMarkup;
  final bool indoPakFontLoaded;

  const _BasmalaHeader({
    required this.mode,
    required this.offlineText,
    required this.onlineText,
    required this.tajweedMarkup,
    required this.indoPakFontLoaded,
  });

  @override
  Widget build(BuildContext context) {
    final indoPak = mode == _ReadingMode.indoPak;
    final style = TextStyle(
      fontFamily:
          indoPak && indoPakFontLoaded ? QuranFontService.indoPakFamily : null,
      fontSize: indoPak ? 30 : 27,
      height: indoPak ? 2.2 : 1.8,
      fontWeight: FontWeight.w600,
    );
    final displayedText = onlineText ?? offlineText;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(
              alpha: 0.38,
            ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: mode != _ReadingMode.uthmani && tajweedMarkup != null
          ? TajweedText(
              markup: tajweedMarkup!,
              displayText: indoPak ? displayedText : null,
              style: style,
              textAlign: TextAlign.center,
            )
          : Text(
              displayedText,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: style,
            ),
    );
  }
}
