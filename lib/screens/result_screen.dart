import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/quran_models.dart';
import '../services/quran_audio_service.dart';

class ResultScreen extends StatefulWidget {
  final Surah surah;
  final Ayah ayah;
  final RecitationResult result;
  final String? userRecordingPath;
  final bool autoPlayReference;

  const ResultScreen({
    super.key,
    required this.surah,
    required this.ayah,
    required this.result,
    this.userRecordingPath,
    this.autoPlayReference = true,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final AudioPlayer _referencePlayer;
  late final AudioPlayer _recordingPlayer;
  late final StreamSubscription<PlayerState> _referenceStateSubscription;
  late final StreamSubscription<PlayerState> _recordingStateSubscription;
  late final StreamSubscription<void> _referenceCompleteSubscription;

  PlayerState _referenceState = PlayerState.stopped;
  PlayerState _recordingState = PlayerState.stopped;
  List<Uri> _referenceQueue = const [];
  int _referenceTrackIndex = 0;

  @override
  void initState() {
    super.initState();
    _referencePlayer = AudioPlayer();
    _recordingPlayer = AudioPlayer();
    _referenceStateSubscription =
        _referencePlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _referenceState = state);
    });
    _recordingStateSubscription =
        _recordingPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _recordingState = state);
    });
    _referenceCompleteSubscription =
        _referencePlayer.onPlayerComplete.listen((_) {
      if (_referenceTrackIndex + 1 < _referenceQueue.length) {
        _referenceTrackIndex++;
        unawaited(_playCurrentReference());
      }
    });

    if (widget.autoPlayReference) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_startReferencePlayback());
      });
    }
  }

  @override
  void dispose() {
    unawaited(_referenceStateSubscription.cancel());
    unawaited(_recordingStateSubscription.cancel());
    unawaited(_referenceCompleteSubscription.cancel());
    unawaited(_referencePlayer.dispose());
    unawaited(_recordingPlayer.dispose());
    super.dispose();
  }

  Future<void> _toggleReferencePlayback() async {
    if (_referenceState == PlayerState.playing) {
      await _referencePlayer.pause();
      return;
    }
    if (_referenceState == PlayerState.paused) {
      await _referencePlayer.resume();
      return;
    }
    await _startReferencePlayback();
  }

  Future<void> _startReferencePlayback() async {
    await _recordingPlayer.stop();
    _referenceQueue = QuranAudioService.referenceQueue(
      surah: widget.surah.number,
      ayah: widget.ayah.number,
    );
    _referenceTrackIndex = 0;
    await _playCurrentReference();
  }

  Future<void> _playCurrentReference() async {
    try {
      await _referencePlayer.play(
        UrlSource(_referenceQueue[_referenceTrackIndex].toString()),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reference audio could not be played. Check your internet connection.',
          ),
        ),
      );
    }
  }

  Future<void> _toggleRecordingPlayback() async {
    final recordingPath = widget.userRecordingPath;
    if (recordingPath == null) return;

    if (_recordingState == PlayerState.playing) {
      await _recordingPlayer.pause();
      return;
    }
    if (_recordingState == PlayerState.paused) {
      await _recordingPlayer.resume();
      return;
    }

    _referenceQueue = const [];
    await _referencePlayer.stop();
    try {
      await _recordingPlayer.play(DeviceFileSource(recordingPath));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your recording could not be replayed.')),
      );
    }
  }

  Future<void> _openAudioSource() async {
    if (!await launchUrl(
          QuranAudioService.sourceHomepage,
          mode: LaunchMode.externalApplication,
        ) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the audio source.')),
      );
    }
  }

  Color _statusColor(BuildContext context, WordStatus status) =>
      switch (status) {
        WordStatus.correct => Colors.green,
        WordStatus.improve => Colors.orange,
        WordStatus.incorrect => Theme.of(context).colorScheme.error,
      };

  String _statusLabel(WordStatus status) => switch (status) {
        WordStatus.correct => 'Correct',
        WordStatus.improve => 'Improve',
        WordStatus.incorrect => 'Retry',
      };

  @override
  Widget build(BuildContext context) {
    final percent = (widget.result.overallScore * 100).round();
    final referencePlaying = _referenceState == PlayerState.playing;
    final recordingPlaying = _recordingState == PlayerState.playing;

    return Scaffold(
      appBar: AppBar(title: const Text('Recitation Feedback')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          Center(
            child: SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: widget.result.overallScore,
                      strokeWidth: 12,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$percent%',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(widget.result.isDemo ? 'demo accuracy' : 'accuracy'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (widget.result.isDemo)
            Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Prototype score only — this is not yet a validated Tajweed assessment.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Listen and compare',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '${QuranAudioService.reciterName} • ${widget.surah.nameEnglish} ${widget.ayah.number}',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonalIcon(
                onPressed: _toggleReferencePlayback,
                icon: Icon(
                  referencePlaying
                      ? Icons.pause_rounded
                      : Icons.volume_up_rounded,
                ),
                label: Text(
                  referencePlaying
                      ? 'Pause correct recitation'
                      : 'Play correct recitation',
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.userRecordingPath == null
                    ? null
                    : _toggleRecordingPlayback,
                icon: Icon(
                  recordingPlaying ? Icons.pause_rounded : Icons.mic_rounded,
                ),
                label: Text(
                  recordingPlaying ? 'Pause my recording' : 'Play my recording',
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _openAudioSource,
              child: const Text('Audio source: Verse By Verse Quran Project'),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Word-by-word review',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.end,
            textDirection: TextDirection.rtl,
            spacing: 8,
            runSpacing: 8,
            children: widget.result.words
                .map(
                  (word) => Chip(
                    label: Text(
                      word.word,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(fontSize: 20),
                    ),
                    avatar: CircleAvatar(
                      backgroundColor: _statusColor(context, word.status),
                      radius: 5,
                    ),
                    side: BorderSide(
                      color: _statusColor(context, word.status)
                          .withValues(alpha: .35),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 22),
          ...widget.result.words
              .where((word) => word.status != WordStatus.correct)
              .map(
                (word) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _statusColor(context, word.status)
                          .withValues(alpha: .13),
                      child: Icon(
                        word.status == WordStatus.incorrect
                            ? Icons.replay_rounded
                            : Icons.tips_and_updates_outlined,
                        color: _statusColor(context, word.status),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          word.word,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _statusLabel(word.status),
                          style: TextStyle(
                            color: _statusColor(context, word.status),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    subtitle:
                        Text('${(word.score * 100).round()}% • ${word.tip}'),
                  ),
                ),
              ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Practice Again'),
          ),
        ],
      ),
    );
  }
}
