import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'services/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // libmpv только на десктопе. На Android используем Media3 (video_player),
  // иначе открытие видео (особенно content:// из MediaStore) приводит
  // к молчаливому вылету libmpv.
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    MediaKit.ensureInitialized();
  }

  final prefs = await SharedPreferences.getInstance();

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
