import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/quran_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/prayer_screen.dart';

void main() {
  runApp(const QuranTutorApp());
}

class QuranTutorApp extends StatefulWidget {
  const QuranTutorApp({super.key});
  @override
  State<QuranTutorApp> createState() => _QuranTutorAppState();
}

class _QuranTutorAppState extends State<QuranTutorApp> {
  ThemeMode mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quran Tarteel',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      home: MainShell(
          onToggleTheme: () => setState(() => mode =
              mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark)),
    );
  }
}

class MainShell extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const MainShell({super.key, required this.onToggleTheme});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  late final pages = const [
    HomeScreen(),
    QuranScreen(),
    ProgressScreen(),
    PrayerScreen()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: index, children: pages),
          Positioned(
              top: MediaQuery.paddingOf(context).top + 6,
              right: 12,
              child: index == 0
                  ? IconButton(
                      onPressed: widget.onToggleTheme,
                      icon: const Icon(Icons.dark_mode_outlined))
                  : const SizedBox.shrink()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded),
              label: 'Quran'),
          NavigationDestination(
              icon: Icon(Icons.auto_graph_outlined),
              selectedIcon: Icon(Icons.auto_graph_rounded),
              label: 'Progress'),
          NavigationDestination(
              icon: Icon(Icons.mosque_outlined),
              selectedIcon: Icon(Icons.mosque_rounded),
              label: 'Prayer'),
        ],
      ),
    );
  }
}
