import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/quran_models.dart';
import '../services/tajweed_service.dart';
import '../widgets/tajweed_text.dart';
import 'recitation_screen.dart';

class SurahScreen extends StatefulWidget {
  final Surah surah;

  const SurahScreen({super.key, required this.surah});

  @override
  State<SurahScreen> createState() => _SurahScreenState();
}

class _SurahScreenState extends State<SurahScreen> {
  late TajweedService _tajweedService;
  late Future<Map<int, String>> _tajweed;
  bool _showTajweed = true;

  @override
  void initState() {
    super.initState();
    _tajweedService = TajweedService();
    _loadTajweed();
  }

  void _loadTajweed() {
    _tajweed = _tajweedService.loadSurah(
      surah: widget.surah.number,
      expectedAyahCount: widget.surah.ayahs.length,
    );
  }

  void _retryTajweed() {
    _tajweedService.dispose();
    setState(() {
      _tajweedService = TajweedService();
      _loadTajweed();
    });
  }

  Future<void> _openSource() async {
    if (!await launchUrl(TajweedService.sourceHomepage)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open quran.foundation.')),
      );
    }
  }

  @override
  void dispose() {
    _tajweedService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.surah.nameEnglish} • ${widget.surah.nameArabic}'),
        actions: [
          IconButton(
            tooltip: _showTajweed ? 'Show plain text' : 'Show Tajweed colours',
            onPressed: () => setState(() => _showTajweed = !_showTajweed),
            icon: Icon(
              _showTajweed ? Icons.palette_rounded : Icons.palette_outlined,
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<int, String>>(
        future: _tajweed,
        builder: (context, snapshot) {
          return Column(
            children: [
              _TajweedControls(
                enabled: _showTajweed,
                loading: _showTajweed &&
                    snapshot.connectionState != ConnectionState.done,
                failed: _showTajweed && snapshot.hasError,
                onChanged: (value) => setState(() => _showTajweed = value),
                onRetry: _retryTajweed,
                onOpenSource: _openSource,
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  itemCount: widget.surah.ayahs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final ayah = widget.surah.ayahs[index];
                    final tajweedMarkup = snapshot.data?[ayah.number];
                    return _AyahCard(
                      surah: widget.surah,
                      ayah: ayah,
                      tajweedMarkup: _showTajweed ? tajweedMarkup : null,
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

class _TajweedControls extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final bool failed;
  final ValueChanged<bool> onChanged;
  final VoidCallback onRetry;
  final VoidCallback onOpenSource;

  const _TajweedControls({
    required this.enabled,
    required this.loading,
    required this.failed,
    required this.onChanged,
    required this.onRetry,
    required this.onOpenSource,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tajweed colours'),
              subtitle: Text(
                !enabled
                    ? 'Plain offline Uthmani text'
                    : failed
                        ? 'Internet unavailable—showing offline Uthmani text'
                        : loading
                            ? 'Loading verified Tajweed annotations…'
                            : 'Colours mark pronunciation rules; schemes vary by Mushaf.',
              ),
              secondary: const Icon(Icons.menu_book_rounded),
              value: enabled,
              onChanged: onChanged,
            ),
            if (enabled && !failed) const TajweedLegend(),
            if (enabled && failed)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry Tajweed colours'),
                ),
              ),
            if (enabled)
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
  final String? tajweedMarkup;

  const _AyahCard({
    required this.surah,
    required this.ayah,
    required this.tajweedMarkup,
  });

  @override
  Widget build(BuildContext context) {
    const arabicStyle = TextStyle(
      fontSize: 30,
      height: 2,
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
            if (tajweedMarkup != null)
              TajweedText(markup: tajweedMarkup!, style: arabicStyle)
            else
              Text(
                ayah.arabic,
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
