import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'services/settings.dart';
import 'ui/shell/app_shell.dart';

class AuraApp extends ConsumerWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final accent =
        accents[settings.accentIndex.clamp(0, accents.length - 1)].color;

    return MaterialApp(
      title: 'AURA Player',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light, accent),
      darkTheme: buildTheme(Brightness.dark, accent),
      themeMode: settings.themeMode,
      home: const AppShell(),
    );
  }
}
