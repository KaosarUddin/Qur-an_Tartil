import 'package:flutter/material.dart';
import '../models/quran_models.dart';

class ResultScreen extends StatelessWidget {
  final Surah surah;
  final Ayah ayah;
  final RecitationResult result;
  const ResultScreen(
      {super.key,
      required this.surah,
      required this.ayah,
      required this.result});

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
    final percent = (result.overallScore * 100).round();
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
                          value: result.overallScore,
                          strokeWidth: 12,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest)),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('$percent%',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    const Text('accuracy')
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 26),
          Text('Word-by-word review',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.end,
            textDirection: TextDirection.rtl,
            spacing: 8,
            runSpacing: 8,
            children: result.words
                .map((w) => Chip(
                      label: Text(w.word,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(fontSize: 20)),
                      avatar: CircleAvatar(
                          backgroundColor: _statusColor(context, w.status),
                          radius: 5),
                      side: BorderSide(
                          color: _statusColor(context, w.status)
                              .withValues(alpha: .35)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 22),
          ...result.words
              .where((w) => w.status != WordStatus.correct)
              .map((w) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                          backgroundColor: _statusColor(context, w.status)
                              .withValues(alpha: .13),
                          child: Icon(
                              w.status == WordStatus.incorrect
                                  ? Icons.replay_rounded
                                  : Icons.tips_and_updates_outlined,
                              color: _statusColor(context, w.status))),
                      title: Row(children: [
                        Text(w.word,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 10),
                        Text(_statusLabel(w.status),
                            style: TextStyle(
                                color: _statusColor(context, w.status),
                                fontWeight: FontWeight.w700))
                      ]),
                      subtitle: Text('${(w.score * 100).round()}% • ${w.tip}'),
                    ),
                  )),
          const SizedBox(height: 18),
          FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Practice Again')),
        ],
      ),
    );
  }
}
