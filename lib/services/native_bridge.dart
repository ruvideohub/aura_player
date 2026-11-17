import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Мост к нативному Kotlin-слою (Android).
/// На Windows и других платформах все методы безопасно возвращают пустой
/// результат — эквалайзер там работает через фильтры mpv.
class NativeBridge {
  static const _channel = MethodChannel('aura.player/native');

  static bool get isAndroid => Platform.isAndroid;

  /// Скан библиотеки устройства через MediaStore.
  /// Возвращает список карт: path, title, artist, album, durationMs,
  /// sizeBytes, addedAt, isVideo.
  static Future<List<Map<String, dynamic>>> scanMedia() async {
    if (!isAndroid) return const [];
    try {
      final res = await _channel.invokeMethod<List<dynamic>>('scanMedia');
      return (res ?? const [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Встроенная обложка из файла (MediaMetadataRetriever).
  static Future<Uint8List?> albumArt(String path) async {
    if (!isAndroid) return null;
    try {
      return await _channel.invokeMethod<Uint8List>('albumArt', {
        'path': path,
      });
    } catch (_) {
      return null;
    }
  }

  static Future<void> setEqEnabled(bool on) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('eqSetEnabled', {'on': on});
    } catch (_) {}
  }

  static Future<void> setEqGains(List<double> gains) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('eqSetGains', {'gains': gains});
    } catch (_) {}
  }

  static Future<void> setBassBoost(int strength) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('eqSetBass', {'strength': strength});
    } catch (_) {}
  }

  // Яркость / громкость — порт твоего Compose-кода без белого оверлея
  static Future<double> getBrightness() async {
    if (!isAndroid) return 0.5;
    try {
      final v = await _channel.invokeMethod<double>('getBrightness');
      return v ?? 0.5;
    } catch (_) { return 0.5; }
  }
  static Future<void> setBrightness(double v) async {
    if (!isAndroid) return;
    try { await _channel.invokeMethod('setBrightness', {'value': v.clamp(0.0, 1.0)}); } catch (_) {}
  }
  static Future<Map<String,int>> getVolume() async {
    if (!isAndroid) return {'cur':50,'max':100};
    try {
      final m = await _channel.invokeMethod<Map<dynamic,dynamic>>('getVolume');
      if (m == null) return {'cur':50,'max':100};
      return {'cur': (m['cur'] as int), 'max': (m['max'] as int)};
    } catch (_) { return {'cur':50,'max':100}; }
  }
  static Future<void> setVolume(int v) async {
    if (!isAndroid) return;
    try { await _channel.invokeMethod('setVolume', {'value': v}); } catch (_) {}
  }
}
