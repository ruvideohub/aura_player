import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Бэкенд для Android на Media3 (ExoPlayer) через video_player.
/// Заменяет libmpv: понимает content://, не требует NDK-либ, даёт SurfaceView.
class AndroidPlayerBackend {
  VideoPlayerController? _controller;
  Timer? _ticker;

  final _positionCtrl = StreamController<Duration>.broadcast();
  final _durationCtrl = StreamController<Duration>.broadcast();
  final _playingCtrl = StreamController<bool>.broadcast();
  final _bufferingCtrl = StreamController<bool>.broadcast();
  final _completedCtrl = StreamController<void>.broadcast();

  // Публичные стримы — совместимы с PlayerController
  Stream<Duration> get positionStream => _positionCtrl.stream;
  Stream<Duration> get durationStream => _durationCtrl.stream;
  Stream<bool> get playingStream => _playingCtrl.stream;
  Stream<bool> get bufferingStream => _bufferingCtrl.stream;
  Stream<void> get completedStream => _completedCtrl.stream;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  Duration _position = Duration.zero;
  Duration get position => _position;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  double _volume = 100;
  double get volume => _volume;

  double _rate = 1.0;
  double get rate => _rate;

  VideoPlayerController? get controller => _controller;

  bool get hasController => _controller != null && _controller!.value.isInitialized;

  /// Создаёт контроллер под путь: content:// или файл.
  VideoPlayerController _create(String rawPath) {
    final path = rawPath.trim();
    if (path.startsWith('content://')) {
      return VideoPlayerController.contentUri(Uri.parse(path));
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return VideoPlayerController.networkUrl(Uri.parse(path));
    }
    // file:// или обычный путь
    final clean = path.startsWith('file://') ? Uri.parse(path).toFilePath() : path;
    return VideoPlayerController.file(File(clean));
  }

  Future<void> open(String path) async {
    await _disposeController();

    final c = _create(path);
    _controller = c;

    try {
      await c.initialize().timeout(const Duration(seconds: 10));
    } catch (e) {
      // не удалось открыть — пробрасываем как ошибку, но не крашим
      _bufferingCtrl.add(false);
      debugPrint('[AndroidPlayer] initialize failed $path : $e');
      return;
    }

    // слушатель состояния
    c.addListener(_onTick);
    _duration = c.value.duration;
    _durationCtrl.add(_duration);
    _bufferingCtrl.add(c.value.isBuffering);

    // применяем сохранённые параметры
    await c.setVolume((_volume / 100).clamp(0.0, 1.0));
    await c.setPlaybackSpeed(_rate);

    _startTicker();

    // автоплей
    try {
      await c.play();
      _isPlaying = true;
      _playingCtrl.add(true);
    } catch (_) {}
  }

  void _onTick() {
    final c = _controller;
    if (c == null) return;
    final v = c.value;

    // длительность могла появиться позже
    if (v.duration != _duration && v.duration > Duration.zero) {
      _duration = v.duration;
      _durationCtrl.add(_duration);
    }

    // позиция
    _position = v.position;
    _positionCtrl.add(_position);

    // playing
    final playing = v.isPlaying;
    if (playing != _isPlaying) {
      _isPlaying = playing;
      _playingCtrl.add(playing);
    }

    // buffering
    _bufferingCtrl.add(v.isBuffering);

    // завершение — duration >0 и позиция в конце и не играет
    if (v.duration > Duration.zero &&
        v.position >= v.duration - const Duration(milliseconds: 500) &&
        !v.isPlaying &&
        !v.isBuffering &&
        v.isInitialized) {
      // защита от ложных срабатываний в начале
      if (_duration > Duration.zero && _position.inMilliseconds > 1000) {
        // однократный сигнал
        if (!_completedFired) {
          _completedFired = true;
          _completedCtrl.add(null);
        }
      }
    } else {
      _completedFired = false;
    }
  }

  bool _completedFired = false;

  void _startTicker() {
    _ticker?.cancel();
    // видео даёт позицию через listener, но для аудио без видео нужен поллинг
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final c = _controller;
      if (c == null || !c.value.isInitialized) return;
      // пушим позицию даже если listener пропустил
      _position = c.value.position;
      _positionCtrl.add(_position);
    });
  }

  Future<void> play() async {
    await _controller?.play();
    _isPlaying = true;
    _playingCtrl.add(true);
  }

  Future<void> pause() async {
    await _controller?.pause();
    _isPlaying = false;
    _playingCtrl.add(false);
  }

  Future<void> playOrPause() async {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration d) async {
    final c = _controller;
    if (c == null) return;
    // кламп
    Duration target = d;
    if (target < Duration.zero) target = Duration.zero;
    if (_duration > Duration.zero && target > _duration) target = _duration;
    await c.seekTo(target);
    _position = target;
    _positionCtrl.add(_position);
  }

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0, 100);
    await _controller?.setVolume((_volume / 100).clamp(0.0, 1.0));
  }

  Future<void> setRate(double r) async {
    _rate = r.clamp(0.25, 2.0);
    await _controller?.setPlaybackSpeed(_rate);
  }

  /// Виджет видео — SurfaceView через Texture (Media3)
  Widget buildVideoView({bool fitCover = false}) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    // VideoPlayer уже отдаёт правильный aspectRatio
    final player = VideoPlayer(c);
    if (fitCover) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: c.value.size.width == 0 ? 1280 : c.value.size.width,
            height: c.value.size.height == 0 ? 720 : c.value.size.height,
            child: player,
          ),
        ),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
        child: player,
      ),
    );
  }

  Future<void> _disposeController() async {
    _ticker?.cancel();
    final c = _controller;
    if (c != null) {
      try {
        c.removeListener(_onTick);
        await c.pause();
        await c.dispose();
      } catch (_) {}
    }
    _controller = null;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
  }

  Future<void> dispose() async {
    await _disposeController();
    _ticker?.cancel();
    // не закрываем broadcast контроллеры — их слушает PlayerController вечно
  }

  void disposeAll() {
    _ticker?.cancel();
    _controller?.dispose();
    _positionCtrl.close();
    _durationCtrl.close();
    _playingCtrl.close();
    _bufferingCtrl.close();
    _completedCtrl.close();
  }
}
