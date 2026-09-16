import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/quran_models.dart';
import '../services/quran_audio_service.dart';
import '../services/recording_source.dart';

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
      await _recordingPlayer.play(recordedAudioSource(recordingPath));
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

  String _issueLabel(FeedbackIssueType type) => switch (type) {
        FeedbackIssueType.missingWord => 'Missing word',
        FeedbackIssueType.missingLetter => 'Missing letter',
        FeedbackIssueType.extraLetter => 'Additional sound',
        FeedbackIssueType.pronunciation => 'Pronunciation',
        FeedbackIssueType.tajweed => 'Tajweed',
        FeedbackIssueType.other => 'Other',
      };

  IconData _issueIcon(FeedbackIssueType type) => switch (type) {
        FeedbackIssueType.missingWord => Icons.playlist_remove_rounded,
        FeedbackIssueType.missingLetter => Icons.text_fields_rounded,
        FeedbackIssueType.extraLetter => Icons.add_comment_outlined,
        FeedbackIssueType.pronunciation => Icons.record_voice_over_rounded,
        FeedbackIssueType.tajweed => Icons.graphic_eq_rounded,
        FeedbackIssueType.other => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final percent = (widget.result.overallScore * 100).round();
    final referencePlaying = _referenceState == PlayerState.playing;
    final recordingPlaying = _recordingState == PlayerState.playing;
    final issues = widget.result.words
        .expand((word) => word.issues)
        .toList(growable: false);
    final wordsWithRules = widget.result.words
        .where((word) => word.rules.isNotEmpty)
        .toList(growable: false);
    final issueCounts = <FeedbackIssueType, int>{};
    for (final issue in issues) {
      issueCounts.update(issue.type, (count) => count + 1, ifAbsent: () => 1);
    }

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
                      Text(
                        widget.result.isDemo
                            ? 'demo accuracy'
                            : widget.result.isExperimental
                                ? 'experimental match'
                                : 'accuracy',
                        textAlign: TextAlign.center,
                      ),
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
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  widget.result.assessmentNotice ??
                      'Demo examples only — no recording was analyzed.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          if (widget.result.isExperimental)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  widget.result.assessmentNotice ??
                      'Experimental speech recognition result. Verify it with '
                          'a qualified teacher.',
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
          if (widget.result.transcript?.isNotEmpty ?? false) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recognizer heard',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.result.transcript!,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (widget.result.extraWords.isNotEmpty) ...[
            const SizedBox(height: 10),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Possible additional words: '
                  '${widget.result.extraWords.join('، ')}',
                  textDirection: TextDirection.rtl,
                ),
              ),
            ),
          ],
          if (wordsWithRules.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text(
              'Expected Tajweed rules',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'These rules come from the annotated Hafs text. They show what '
              'to practise; they are not yet measurements of your audio.',
            ),
            const SizedBox(height: 10),
            ...wordsWithRules.map(
              (word) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          word.word,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: word.rules
                              .map(
                                (rule) => Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(
                                    Icons.graphic_eq_rounded,
                                    size: 17,
                                  ),
                                  label: Text(rule),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          if (issues.isNotEmpty) ...[
            Text(
              'Details to practise',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: issueCounts.entries
                  .map(
                    (entry) => Chip(
                      avatar: Icon(_issueIcon(entry.key), size: 18),
                      label: Text('${_issueLabel(entry.key)} · ${entry.value}'),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 10),
          ],
          ...widget.result.words
              .where((word) => word.status != WordStatus.correct)
              .map(
                (word) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  _statusColor(context, word.status)
                                      .withValues(alpha: .13),
                              child: Icon(
                                word.status == WordStatus.incorrect
                                    ? Icons.replay_rounded
                                    : Icons.tips_and_updates_outlined,
                                color: _statusColor(context, word.status),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                word.word,
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${_statusLabel(word.status)} '
                              '${(word.score * 100).round()}%',
                              style: TextStyle(
                                color: _statusColor(context, word.status),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(word.tip),
                        if (word.observed != null &&
                            word.observed != word.word) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Recognized as: ${word.observed}',
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                        ...word.issues.map(
                          (issue) => Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: .55),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(_issueIcon(issue.type), size: 19),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            issue.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        if (issue.rule != null)
                                          Chip(
                                            visualDensity:
                                                VisualDensity.compact,
                                            label: Text(issue.rule!),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(issue.detail),
                                    if (issue.expected != null ||
                                        issue.observed != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        issue.expected != null &&
                                                issue.observed != null
                                            ? 'Expected: ${issue.expected}  •  '
                                                'Heard: ${issue.observed}'
                                            : issue.expected != null
                                                ? 'Expected: ${issue.expected}'
                                                : 'Heard: ${issue.observed}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                    if (issue.suggestion.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text('Try: ${issue.suggestion}'),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
