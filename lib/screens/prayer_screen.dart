import 'package:flutter/material.dart';

class PrayerScreen extends StatelessWidget {
  const PrayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const prayers = [
      ('Fajr', '5:12 AM'),
      ('Dhuhr', '12:41 PM'),
      ('Asr', '4:09 PM'),
      ('Maghrib', '6:52 PM'),
      ('Isha', '8:08 PM')
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Prayer & Qibla')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(children: [
                Icon(Icons.explore_rounded,
                    size: 58, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Text('Qibla',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text(
                    'Compass integration placeholder. Production version will use device sensors and verified Kaaba bearing calculation.'),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          Text('Prayer times',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
              'Demo only — production version will calculate from user-selected location and method.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          ...prayers.map((p) => Card(
              child: ListTile(
                  leading: const Icon(Icons.access_time_rounded),
                  title: Text(p.$1),
                  trailing: Text(p.$2,
                      style: const TextStyle(fontWeight: FontWeight.w700))))),
        ],
      ),
    );
  }
}
