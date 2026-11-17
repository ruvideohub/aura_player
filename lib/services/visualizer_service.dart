import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Сервис реального аудио-визуализатора.
/// На Android — берёт FFT/waveform из Visualizer API (нативные данные).
/// На Windows/macOS/Linux — пока фоллбек к анализу громкости/позиции (фейк с энтропией).
class VisualizerService {
  static const _channel = MethodChannel('aura.player/native');
  static const _event = EventChannel('aura.player/visualizer');

  static Stream<Map<String, List<int>>>? _realStream;
  static StreamSubscription? _sub;

  /// Пробуем запросить разрешение на микрофон (нужно для Visualizer output mix)
  static Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final s = await Permission.microphone.request();
      return s.isGranted || s.isLimited;
    } catch (_) { return false; }
  }

  static Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final s = await Permission.microphone.status;
      return s.isGranted || s.isLimited;
    } catch (_) { return false; }
  }

  /// Инициализировать нативный визуализатор с sessionId 0 (output mix)
  static Future<bool> init({int sessionId = 0}) async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('initVisualizer', {'sessionId': sessionId});
      return ok ?? false;
    } catch (_) { return false; }
  }

  static Future<void> setEnabled(bool en) async {
    if (!Platform.isAndroid) return;
    try { await _channel.invokeMethod('setVisualizerEnabled', {'enabled': en}); } catch (_) {}
  }

  /// Поток реальных данных: каждый event = {"fft":[int...], "waveform":[int...]}
  static Stream<Map<String, List<int>>> realStream({int sessionId = 0, int rate = 20000}) {
    if (_realStream != null) return _realStream!;
    if (!Platform.isAndroid) return const Stream.empty();
    // EventChannel с аргументами
    final stream = _event.receiveBroadcastStream({'sessionId': sessionId, 'rate': rate})
        .map((e) {
          if (e is Map) {
            final fft = (e['fft'] as List?)?.cast<int>() ?? const <int>[];
            final wave = (e['waveform'] as List?)?.cast<int>() ?? const <int>[];
            return {'fft': fft, 'waveform': wave};
          }
          return <String, List<int>>{'fft': [], 'waveform': []};
        })
        .asBroadcastStream();
    _realStream = stream;
    return stream;
  }

  static void dispose() {
    _sub?.cancel();
    _realStream = null;
  }
}

/// Утилиты для конвертации нативных данных в уровни для отрисовки
class VizData {
  /// FFT в формате Visualizer: 128 байт, каждые 2 байта = комплексное число (real, imag) -> magnitude
  /// Преобразуем в уровни 0..1 для N баров
  static List<double> fftToLevels(List<int> fftBytes, int barCount) {
    if (fftBytes.isEmpty) return List.filled(barCount, 0.0);
    // fftBytes unsigned 0..255, в native это signed byte -128..127; мы получили unsigned, конвертим
    // magnitude = sqrt(re^2 + im^2)
    final n = fftBytes.length ~/ 2; // комплексные пары
    final mags = <double>[];
    for (var i = 0; i < n; i++) {
      final rawRe = fftBytes[i*2];
      final rawIm = fftBytes[i*2+1];
      // signed
      final re = rawRe > 127 ? rawRe - 256 : rawRe;
      final im = rawIm > 127 ? rawIm - 256 : rawIm;
      final mag = math.sqrt(re*re + im*im);
      mags.add(mag);
    }
    // mags: 0..~181, логарифмируем
    // группируем в barCount, усредняем с весами (больше басов слева)
    final out = List.filled(barCount, 0.0);
    for (var i = 0; i < barCount; i++) {
      // логарифмическое распределение: басы занимают больше индексов
      final start = (math.pow(i / barCount, 0.8) * n).floor();
      final end = (math.pow((i+1) / barCount, 0.8) * n).floor().clamp(start+1, n);
      double sum = 0;
      for (var j = start; j < end; j++) sum += mags[j];
      final avg = sum / (end - start);
      // нормализация: 0..181 -> 0..1 с компрессией
      final norm = (math.log(1 + avg) / math.log(1 + 128)).clamp(0.0, 1.0);
      out[i] = norm;
    }
    return out;
  }

  /// Waveform: 0..255 unsigned, центр 128 -> -1..1
  static List<double> waveformToWave(List<int> waveBytes) {
    if (waveBytes.isEmpty) return [];
    return waveBytes.map((v) => (v - 128) / 128.0).toList();
  }

  /// Альтернатива: если нет реальных данных — генерируем псевдо-реальные уровни на основе позиции/времени с энтропией
  static List<double> fakeLevels(int barCount, Duration position, bool playing, math.Random rng) {
    final t = position.inMilliseconds / 1000.0;
    final levels = List.filled(barCount, 0.0);
    for (var i = 0; i < barCount; i++) {
      // используем позицию как сид для шума — меньше цикличности
      final n = (math.sin(t * 3 + i * 0.7) * 0.5 + 0.5) * 0.6 +
                (math.sin(t * 7.3 + i * 1.3) * 0.5 + 0.5) * 0.3 +
                rng.nextDouble() * 0.08;
      levels[i] = (n * (playing ? 1 : 0.08)).clamp(0.04, 1.0);
    }
    return levels;
  }
}
