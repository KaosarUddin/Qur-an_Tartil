import 'package:flutter/material.dart';
import '../models/quran_models.dart';
import 'recitation_screen.dart';

class SurahScreen extends StatelessWidget {
  final Surah surah;
  const SurahScreen({super.key, required this.surah});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${surah.nameEnglish} • ${surah.nameArabic}')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        itemCount: surah.ayahs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final ayah = surah.ayahs[index];
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
                          tooltip: 'Listen (next milestone)',
                          onPressed: () => ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                                  content: Text(
                                      'Reciter audio will be connected in the next milestone.')))),
                      IconButton(
                          icon: const Icon(Icons.mic_rounded),
                          tooltip: 'Practice',
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => RecitationScreen(
                                      surah: surah, ayah: ayah)))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(ayah.arabic,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                          fontSize: 30,
                          height: 2.0,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  if (ayah.translation.isNotEmpty)
                    Text(ayah.translation,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
