import 'package:flutter/material.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Progress')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Row(children: [
            Expanded(
                child: _Metric(
                    label: 'Practice streak',
                    value: '4 days',
                    icon: Icons.local_fire_department_outlined)),
            SizedBox(width: 12),
            Expanded(
                child: _Metric(
                    label: 'Avg. accuracy',
                    value: '86%',
                    icon: Icons.track_changes_rounded)),
          ]),
          const SizedBox(height: 22),
          Text('Learning journey',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          const Card(
              child: ListTile(
                  leading: Icon(Icons.check_circle_outline_rounded),
                  title: Text('Al-Fatihah'),
                  subtitle: Text('5 practice sessions • Demo progress'),
                  trailing: Text('91%'))),
          const SizedBox(height: 10),
          const Card(
              child: ListTile(
                  leading: Icon(Icons.radio_button_unchecked_rounded),
                  title: Text('Al-Ikhlas'),
                  subtitle: Text('2 practice sessions • Demo progress'),
                  trailing: Text('82%'))),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Metric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon),
            const SizedBox(height: 16),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900)),
            Text(label)
          ])));
}
