import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../widgets/feature_card.dart';
import 'quran_screen.dart';
import 'prayer_screen.dart';
import 'progress_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'السَّلَامُ عَلَيْكُمْ وَرَحْمَةُ اللَّهِ وَبَرَكَاتُهُ',
                      textDirection: TextDirection.rtl,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text('Continue your Quran journey',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppTheme.deepEmerald,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TODAY’S PRACTICE',
                    style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .9)),
                const SizedBox(height: 10),
                const Text('Al-Fatihah • Ayah 1',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                          color: Colors.white, fontSize: 27, height: 1.8)),
                ),
                const SizedBox(height: 14),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.deepEmerald),
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const QuranScreen())),
                  icon: const Icon(Icons.mic_rounded),
                  label: const Text('Practice recitation'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Explore',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          FeatureCard(
              icon: Icons.menu_book_rounded,
              title: 'Read Quran',
              subtitle: 'Surah, Ayah and listening practice',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const QuranScreen()))),
          const SizedBox(height: 10),
          FeatureCard(
              icon: Icons.auto_graph_rounded,
              title: 'My Progress',
              subtitle: 'Accuracy, streaks and recent practice',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProgressScreen()))),
          const SizedBox(height: 10),
          FeatureCard(
              icon: Icons.mosque_outlined,
              title: 'Prayer & Qibla',
              subtitle: 'Prayer-time and Qibla modules',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrayerScreen()))),
        ],
      ),
    );
  }
}
