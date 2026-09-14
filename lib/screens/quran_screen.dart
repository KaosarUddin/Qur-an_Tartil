import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/quran_repository.dart';
import '../models/quran_models.dart';
import 'surah_screen.dart';

class QuranScreen extends StatelessWidget {
  const QuranScreen({super.key});

  static final _tanzilUri = Uri.parse('https://tanzil.net');

  Future<void> _openTanzil(BuildContext context) async {
    if (!await launchUrl(_tanzilUri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open tanzil.net.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quran • 114 Surahs')),
      body: FutureBuilder<List<Surah>>(
        future: QuranRepository.load(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'The Quran text could not be loaded.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final surahs = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            itemCount: surahs.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == surahs.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: TextButton.icon(
                    onPressed: () => _openTanzil(context),
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text(
                      'Quran text: Tanzil Project • CC BY 3.0',
                    ),
                  ),
                );
              }

              final surah = surahs[index];
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                leading: CircleAvatar(child: Text('${surah.number}')),
                title: Text(
                  surah.nameEnglish,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(surah.revelation),
                trailing: Text(
                  surah.nameArabic,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => SurahScreen(surah: surah)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
