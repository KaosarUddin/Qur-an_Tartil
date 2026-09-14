import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../models/quran_models.dart';
import '../services/api_service.dart';
import '../services/quran_font_service.dart';
import '../services/recording_path.dart';
import '../widgets/tajweed_text.dart';
import 'result_screen.dart';

class RecitationScreen extends StatefulWidget {
  final Surah surah;
  final Ayah ayah;
  final String? displayText;
  final String? tajweedMarkup;
  final bool useIndoPakFont;

  const RecitationScreen({
    super.key,
    required this.surah,
    required this.ayah,
    this.displayText,
    this.tajweedMarkup,
    this.useIndoPakFont = false,
  });

  @override
  State<RecitationScreen> createState() => _RecitationScreenState();
}

class _RecitationScreenState extends State<RecitationScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  bool _analyzing = false;
  String? _audioPath;

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await _recorder.stop();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _audioPath = path;
      });
      return;
    }
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Microphone permission is required.')));
      }
      return;
    }
    final path = await createRecordingPath();
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path);
    if (mounted) {
      setState(() {
        _recording = true;
        _audioPath = null;
      });
    }
  }

  Future<void> _analyze() async {
    setState(() => _analyzing = true);
    final result = await ApiService().analyzeRecitation(
      surah: widget.surah.number,
      ayah: widget.ayah.number,
      expectedText: widget.ayah.arabic,
      audioPath: _audioPath,
    );
    if (!mounted) return;
    setState(() => _analyzing = false);
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ResultScreen(
            surah: widget.surah,
            ayah: widget.ayah,
            result: result,
            userRecordingPath: _audioPath)));
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ayahStyle = TextStyle(
      fontFamily: widget.useIndoPakFont ? QuranFontService.indoPakFamily : null,
      fontSize: widget.useIndoPakFont ? 38 : 36,
      height: widget.useIndoPakFont ? 2.4 : 2,
      fontWeight: FontWeight.w600,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Recitation Practice')),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Text('${widget.surah.nameEnglish} • Ayah ${widget.ayah.number}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 30),
            Expanded(
              child: Center(
                child: widget.tajweedMarkup != null
                    ? TajweedText(
                        markup: widget.tajweedMarkup!,
                        displayText: widget.displayText,
                        style: ayahStyle,
                        textAlign: TextAlign.center,
                      )
                    : Text(
                        widget.displayText ?? widget.ayah.arabic,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: ayahStyle,
                      ),
              ),
            ),
            Text(
                _recording
                    ? 'Recording… tap to stop'
                    : _audioPath == null
                        ? 'Tap the microphone and recite the Ayah'
                        : 'Recording ready for AI check',
                textAlign: TextAlign.center),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: _toggleRecording,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _recording
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                  boxShadow: [
                    BoxShadow(
                        blurRadius: 20,
                        color: (_recording
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.primary)
                            .withValues(alpha: .22))
                  ],
                ),
                child: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white, size: 42),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _recording || _analyzing ? null : _analyze,
                icon: _analyzing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(_analyzing
                    ? 'Analyzing…'
                    : _audioPath == null
                        ? 'Try AI Demo'
                        : 'Check My Recitation'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
                'MVP: feedback is currently simulated. Replace backend scorer with validated Quranic ASR/pronunciation models before production.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
