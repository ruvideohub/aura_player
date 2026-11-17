import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'models/models.dart';
import 'services/launch_args.dart';
import 'services/settings.dart';

String? _extractInitialPath(List<String> args) {
  for (final a in args) {
    final s = a.trim();
    if (s.isEmpty) continue;
    // пропускаем флаги
    if (s.startsWith('-')) continue;
    // Windows может передавать в кавычках, убираем
    var p = s;
    if ((p.startsWith('"') && p.endsWith('"')) || (p.startsWith("'") && p.endsWith("'"))) {
      p = p.substring(1, p.length - 1);
    }
    // Проверяем расширение или существование
    final looksLikePath = p.contains(':') || p.contains('/') || p.contains(r'\');
    if (!looksLikePath) continue;
    // Подходит если это видео/аудио/поток
    if (isVideoPath(p) || isAudioPath(p) || isStreamUrl(p)) return p;
    // Фоллбек: если файл существует с любым именем — пробуем открыть как медиа
    try {
      if (File(p).existsSync()) return p;
    } catch (_) {}
  }
  return null;
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // libmpv только на десктопе. На Android используем Media3 (video_player),
  // иначе открытие видео (особенно content:// из MediaStore) приводит
  // к молчаливому вылету libmpv.
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    MediaKit.ensureInitialized();
  }

  final prefs = await SharedPreferences.getInstance();

  // Запоминаем путь из ассоциации (двойной клик по файлу на Windows)
  if (args.isNotEmpty) {
    final p = _extractInitialPath(args);
    if (p != null) setInitialLaunchPath(p);
  }

  final isDesktop =
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  if (isDesktop) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        title: 'AURA Player',
        size: Size(1280, 820),
        minimumSize: Size(1000, 680),
        center: true,
        backgroundColor: Colors.transparent,
        titleBarStyle: TitleBarStyle.hidden,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) {
          final controller = SettingsController(prefs);
          ref.onDispose(controller.dispose);
          return controller;
        }),
      ],
      child: const AuraApp(),
    ),
  );
}
