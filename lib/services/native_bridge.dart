import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Мост к нативному Kotlin-слою (Android).
/// На Windows и других платформах все методы безопасно возвращают пустой
/// результат — эквалайзер там работает через фильтры mpv.
class NativeBridge {
  static const _channel = MethodChannel('aura.player/native');

  static bool get isAndroid => Platform.isAndroid;

  // ── подписчики на media actions ───────────────────────────────
  static final _actionCtrl = StreamController<String>.broadcast();
  static Stream<String> get mediaActions => _actionCtrl.stream;
  static bool _handlerSet = false;

  static void ensureHandler() {
    if (_handlerSet) return;
    _handlerSet = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'mediaAction') {
        final a = call.arguments is Map ? (call.arguments as Map)['action'] as String? : null;
        if (a != null) _actionCtrl.add(a);
      } else if (call.method == 'onUserLeaveHint') {
        _actionCtrl.add('AURA_LEAVE_HINT');
      } else if (call.method == 'pipChanged') {
        final inPip = call.arguments is Map ? (call.arguments as Map)['inPip'] as bool? : null;
        _actionCtrl.add(inPip == true ? 'AURA_PIP_ENTER' : 'AURA_PIP_EXIT');
      }
    });
    // проверим pending action при старте
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        final a = await _channel.invokeMethod<String>('consumeMediaAction');
        if (a != null && a.startsWith('AURA_')) _actionCtrl.add(a);
      } catch (_) {}
    });
  }

  /// Скан библиотеки устройства через MediaStore.
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

  static Future<Uint8List?> albumArt(String path) async {
    if (!isAndroid) return null;
    try {
      return await _channel.invokeMethod<Uint8List>('albumArt', {'path': path});
    } catch (_) {
      return null;
    }
  }

  static Future<void> setEqEnabled(bool on) async {
    if (!isAndroid) return;
    try { await _channel.invokeMethod('eqSetEnabled', {'on': on}); } catch (_) {}
  }
  static Future<void> setEqGains(List<double> gains) async {
    if (!isAndroid) return;
    try { await _channel.invokeMethod('eqSetGains', {'gains': gains}); } catch (_) {}
  }
  static Future<void> setBassBoost(int strength) async {
    if (!isAndroid) return;
    try { await _channel.invokeMethod('eqSetBass', {'strength': strength}); } catch (_) {}
  }

  static Future<double> getBrightness() async {
    if (!isAndroid) return 0.5;
    try { final v = await _channel.invokeMethod<double>('getBrightness'); return v ?? 0.5; } catch (_) { return 0.5; }
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
  static Future<Uint8List?> videoThumb(String path) async {
    if (!isAndroid) return null;
    try { return await _channel.invokeMethod<Uint8List>('videoThumb', {'path': path}); } catch (_) { return null; }
  }

  // ── Уведомление / фон (только музыка) ───────────────────────
  static Future<void> showNotification({required String title, String artist = '', bool isPlaying = true, int pos = 0, int dur = 0}) async {
    if (!isAndroid) return;
    try { await _channel.invokeMethod('showNotification', {'title': title, 'artist': artist, 'isPlaying': isPlaying, 'pos': pos, 'dur': dur}); } catch (_) {}
  }
  static Future<void> updateNotification({required String title, String artist = '', bool isPlaying = true, int pos = 0, int dur = 0}) async {
    if (!isAndroid) return;
    try { await _channel.invokeMethod('updateNotification', {'title': title, 'artist': artist, 'isPlaying': isPlaying, 'pos': pos, 'dur': dur}); } catch (_) {}
  }
  static Future<void> hideNotification() async {
    if (!isAndroid) return;
    try { await _channel.invokeMethod('hideNotification'); } catch (_) {}
  }
  static Future<void> requestNotifPermission() async {
    if (!isAndroid) return;
    try { await _channel.invokeMethod('requestNotifPermission'); } catch (_) {}
  }

  // ── PiP ─────────────────────────────────────────────────────
  static Future<bool> enterPip({int width = 16, int height = 9}) async {
    if (!isAndroid) return false;
    try { final r = await _channel.invokeMethod<bool>('enterPip', {'width': width, 'height': height}); return r ?? false; } catch (_) { return false; }
  }
  static Future<bool> isPipSupported() async {
    if (!isAndroid) return false;
    try { final r = await _channel.invokeMethod<bool>('isPipSupported'); return r ?? false; } catch (_) { return false; }
  }
}
