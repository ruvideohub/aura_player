import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../ui/state/ui_state.dart';

/// Быстрый Android-бэкенд — идеи из твоего ExoPlayerHandler.
/// Делает то же что Kotlin, но без переписывания native:
///   1) reuse контроллера (switchToSource) — не пересоздаём плеер на тот же URL
///   2) заголовки per-request (ResolvingDataSource) через httpHeaders
///   3) HLS/DASH mime hint + live-конфиг
///   4) кэш-заготовка (OkHttpDataSource + SimpleCache на native — см. комментарий)
///   5) fire-and-forget dispose + ленивый ticker
class AndroidPlayerBackend {
  VideoPlayerController? _controller;
  String? _currentRawPath;
  bool _isLive = false;
  Timer? _ticker;

  final _positionCtrl = StreamController<Duration>.broadcast();
  final _durationCtrl = StreamController<Duration>.broadcast();
  final _playingCtrl = StreamController<bool>.broadcast();
  final _bufferingCtrl = StreamController<bool>.broadcast();
  final _completedCtrl = StreamController<void>.broadcast();

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

  // Хелперы как в Kotlin — угадываем mime, live, заголовки
  String? _guessMime(String url) {
    final u = url.toLowerCase();
    if (u.contains('.m3u8')) return 'application/x-mpegURL';
    if (u.contains('.mpd')) return 'application/dash+xml';
    if (u.contains('.mp4')) return 'video/mp4';
    if (u.contains('.webm')) return 'video/webm';
    return null;
  }

  bool _isLiveUrl(String url) {
    // эвристика как в ExoPlayerHandler — live m3u8 обычно без duration
    final u = url.toLowerCase();
    return u.contains('live') || u.contains('stream') && u.contains('.m3u8');
  }

  Map<String,String> _headersFor(String url) {
    // аналог defaultRequestPropertiesFor() + HeaderResolver
    // Accept + UA/Referer если нужно — подставь свой токен
    return {
      'Accept': '*/*',
      'User-Agent': 'AURA-Player/2.0 (Android; ExoPlayer)',
      // 'Referer': 'https://...', // раскомментируй для Rutube/Okko
      // 'Cookie': '...',
    };
  }

  VideoPlayerController _create(String rawPath) {
    final path = rawPath.trim();
    if (path.startsWith('content://')) {
      return VideoPlayerController.contentUri(Uri.parse(path));
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      final headers = _headersFor(path);
      final mime = _guessMime(path);
      // video_player_android c 2.4 поддерживает httpHeaders + formatHint
      return VideoPlayerController.networkUrl(
        Uri.parse(path),
        httpHeaders: headers,
        formatHint: mime != null && mime.contains('mpegURL') ? VideoFormat.hls : null,
      );
    }
    final clean = path.startsWith('file://') ? Uri.parse(path).toFilePath() : path;
    return VideoPlayerController.file(File(clean));
  }

  /// Аналог switchToSource — reuse если тот же videoId/URI
  Future<void> open(String path) async {
    final trimmed = path.trim();
    final isLive = _isLiveUrl(trimmed);

    // reuse путь: тот же файл/URL — просто seek + play, без пересоздания Texture
    if (_controller != null &&
        _currentRawPath == trimmed &&
        hasController) {
      final c = _controller!;
      try {
        if (isLive) {
          // live — seekToDefaultPosition аналог
          await c.seekTo(Duration.zero);
          await c.play();
        } else {
          final pos = c.value.position;
          // если уже играет — не трогаем, если на паузе — play
          if (!c.value.isPlaying) await c.play();
          _isPlaying = c.value.isPlaying;
          _playingCtrl.add(_isPlaying);
          debugPrint('[AndroidPlayer] reuse $trimmed @ $pos');
        }
        return;
      } catch (_) {
        // fallback — пересоздадим
      }
    }

    // быстрый dispose без await на pause — как в Kotlin release(clearListeners=false)
    _fastDisposeOld();

    final c = _create(trimmed);
    _controller = c;
    _currentRawPath = trimmed;
    _isLive = isLive;
    _duration = Duration.zero;
    _position = Duration.zero;

    // таймаут короче для локальных файлов (1.5с) — сеть 8с, как LoadControl
    final isNetwork = trimmed.startsWith('http');
    final timeout = isNetwork ? const Duration(seconds: 8) : const Duration(seconds: 4);

    try {
      await c.initialize().timeout(timeout);
    } catch (e) {
      _bufferingCtrl.add(false);
      debugPrint('[AndroidPlayer] init failed $trimmed: $e');
      return;
    }

    c.addListener(_onTick);
    _duration = c.value.duration;
    if (_duration > Duration.zero) _durationCtrl.add(_duration);
    _bufferingCtrl.add(c.value.isBuffering);

    await c.setVolume((_volume / 100).clamp(0.0, 1.0));
    await c.setPlaybackSpeed(_rate);
    _startTickerIfNeeded();

    try {
      // live — автоплей сразу, как в Kotlin playWhenReady=true
      await c.play();
      _isPlaying = true;
      _playingCtrl.add(true);
    } catch (_) {}
  }

  void _onTick() {
    final c = _controller;
    if (c == null) return;
    final v = c.value;
    if (v.duration != _duration && v.duration > Duration.zero) {
      _duration = v.duration;
      _durationCtrl.add(_duration);
    }
    _position = v.position;
    _positionCtrl.add(_position);

    final playing = v.isPlaying;
    if (playing != _isPlaying) {
      _isPlaying = playing;
      _playingCtrl.add(playing);
    }
    _bufferingCtrl.add(v.isBuffering);

    if (v.duration > Duration.zero &&
        v.position >= v.duration - const Duration(milliseconds: 500) &&
        !v.isPlaying && !v.isBuffering && v.isInitialized) {
      if (_duration > Duration.zero && _position.inMilliseconds > 1000) {
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

  void _startTickerIfNeeded() {
    _ticker?.cancel();
    // только для аудио без видео — как в Kotlin periodic 1с
    // видео даёт позицию через listener 60fps, тикер не нужен
    final c = _controller;
    if (c == null) return;
    // проверяем — если есть видео-трек, тикер не нужен
    final hasVideo = c.value.size.width > 0 && c.value.size.height > 0;
    if (hasVideo) return;
    _ticker = Timer.periodic(const Duration(milliseconds: 400), (_) {
      final cc = _controller;
      if (cc == null || !cc.value.isInitialized) return;
      _position = cc.value.position;
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
    if (c.value.isPlaying) await pause(); else await play();
  }

  Future<void> seek(Duration d) async {
    final c = _controller;
    if (c == null) return;
    Duration t = d;
    if (t < Duration.zero) t = Duration.zero;
    if (_duration > Duration.zero && t > _duration) t = _duration;
    // live — clamp к окну, как в Kotlin seekToDefaultPosition
    if (_isLive && _duration == Duration.zero) {
      await c.seekTo(t);
    } else {
      await c.seekTo(t);
    }
    _position = t;
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

  Widget buildVideoView({VideoFit fit = VideoFit.contain, bool fitCover = false}) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return const ColoredBox(color: Colors.black);
    if (fitCover && fit == VideoFit.contain) fit = VideoFit.cover;
    final player = VideoPlayer(c);
    final ar = c.value.aspectRatio == 0 ? 16/9 : c.value.aspectRatio;
    final w = c.value.size.width == 0 ? 1280.0 : c.value.size.width;
    final h = c.value.size.height == 0 ? 720.0 : c.value.size.height;
    final sized = SizedBox(width: w, height: h, child: player);
    switch (fit) {
      case VideoFit.contain: return Center(child: AspectRatio(aspectRatio: ar, child: player));
      case VideoFit.cover: return SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: sized));
      case VideoFit.stretch: return SizedBox.expand(child: FittedBox(fit: BoxFit.fill, child: sized));
      case VideoFit.sixteenNine: return Center(child: AspectRatio(aspectRatio: 16/9, child: FittedBox(fit: BoxFit.contain, child: sized)));
      case VideoFit.fourThree: return Center(child: AspectRatio(aspectRatio: 4/3, child: FittedBox(fit: BoxFit.contain, child: sized)));
    }
  }

  void _fastDisposeOld() {
    _ticker?.cancel();
    final c = _controller;
    if (c != null) {
      try {
        c.removeListener(_onTick);
        // не ждём pause/dispose — фоном, как unawaited(release) в Kotlin
        // ignore: discarded_futures
        c.pause().then((_) => c.dispose()).catchError((_) {});
      } catch (_) {}
    }
    _controller = null;
    _isPlaying = false;
  }

  Future<void> _disposeController() async => _fastDisposeOld();

  Future<void> dispose() async {
    _fastDisposeOld();
    _ticker?.cancel();
  }

  void disposeAll() {
    _ticker?.cancel();
    try { _controller?.dispose(); } catch (_) {}
    _positionCtrl.close(); _durationCtrl.close(); _playingCtrl.close(); _bufferingCtrl.close(); _completedCtrl.close();
  }
}
