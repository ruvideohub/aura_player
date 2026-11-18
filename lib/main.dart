import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:http/http.dart' as http;

import 'app.dart';
import 'models/models.dart';
import 'services/launch_args.dart';
import 'services/settings.dart';
import 'services/vk_music/vk_music_api.dart';
import 'services/vk_music/vk_token_storage.dart';
import 'ui/pages/vk_music/vk_music_page.dart';

String? _extractInitialPath(List<String> args) {
  for (final a in args) {
    final s = a.trim();
    if (s.isEmpty) continue;
    if (s.startsWith('-')) continue;
    var p = s;
    if ((p.startsWith('"') && p.endsWith('"')) || (p.startsWith("'") && p.endsWith("'"))) {
      p = p.substring(1, p.length - 1);
    }
    final looksLikePath = p.contains(':') || p.contains('/') || p.contains(r'\');
    if (!looksLikePath) continue;
    if (isVideoPath(p) || isAudioPath(p) || isStreamUrl(p)) return p;
    try {
      if (File(p).existsSync()) return p;
    } catch (_) {}
  }
  return null;
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    MediaKit.ensureInitialized();
  }

  final prefs = await SharedPreferences.getInstance();

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
        backgroundColor: Color(0xFF0A0A0A),
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
        sharedPrefsProvider.overrideWithValue(prefs),
        vkMusicApiProvider.overrideWith((ref) {
          final sp = ref.watch(sharedPrefsProvider);
          return VkMusicApi(http.Client(), VkTokenStorage(sp));
        }),
      ],
      child: const AuraApp(),
    ),
  );
}
