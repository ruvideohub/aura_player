import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart' as vp;

import '../core/lrc.dart';
import '../models/models.dart';
import '../services/android_player_backend.dart';
import '../services/library.dart';
import '../services/native_bridge.dart';
import '../services/settings.dart';
import '../ui/state/ui_state.dart';

/// Центральный контроллер плеера: очередь, шаффл, повтор,
/// восстановление позиции, эквалайзер, таймер сна.
///
/// Desktop (Windows/Linux/macOS): libmpv через media_kit — все форматы, субтитры, EQ firequalizer
/// Android: Media3 (ExoPlayer) через video_player —SurfaceView, понимает content://, не крашится
class PlayerController extends ChangeNotifier {
  PlayerController(this._ref) {
    _isAndroid = Platform.isAndroid;
    if (_isAndroid) {
      final backend = AndroidPlayerBackend();
      _androidBackend = backend;
      videoController = null;
      _player = null;
      _subs = [
        backend.positionStream.listen(_onPosition),
        backend.durationStream.listen((d) {
          _duration = d;
          _resolveResume();
          _updateDurationInLibrary();
          notifyListeners();
        }),
        backend.playingStream.listen((v) {
          final was = _playing;
          _playing = v;
          notifyListeners();
          if (was && !v) _maybeResumeMusicAfterSystemPause();
        }),
        backend.bufferingStream.listen((v) {
          _buffering = v;
          notifyListeners();
        }),
        backend.completedStream.listen((_) {
          next(manual: false);
        }),
      ];
    } else {
      // Desktop — libmpv
      final player = Player(
        configuration: const PlayerConfiguration(
          bufferSize: 64 * 1024 * 1024,
        ),
      );
      _player = player;
      videoController = VideoController(
        player,
        configuration: VideoControllerConfiguration(
          enableHardwareAcceleration: false,
        ),
      );
      _androidBackend = null;
      _subs = [
        player.stream.playing.listen((v) {
          final was = _playing;
          _playing = v;
          notifyListeners();
          if (was && !v) _maybeResumeMusicAfterSystemPause();
        }),
        player.stream.position.listen(_onPosition),
        player.stream.duration.listen((d) {
          _duration = d;
          _resolveResume();
          _updateDurationInLibrary();
          notifyListeners();
        }),
        player.stream.completed.listen((c) {
          if (c) next(manual: false);
        }),
        player.stream.volume.listen((v) {
          _volume = v;
          notifyListeners();
        }),
        player.stream.rate.listen((r) {
          _rate = r;
          notifyListeners();
        }),
        player.stream.buffering.listen((v) {
          _buffering = v;
          notifyListeners();
        }),
      ];
    }
    // Восстановление очереди после загрузки библиотеки
    Future.microtask(() => _restoreQueue());
  }

  Future<void> _persistQueue() async {
    try {
      await _library.saveQueue(queue, index, shuffle, repeat.name);
    } catch (_) {}
  }

  Future<void> _restoreQueue() async {
    if (_queueRestored) return;
    _queueRestored = true;
    try {
      final data = await _library.loadQueue();
      if (data == null) return;
      final q = (data['queue'] as List?)?.map((e) => MediaTrack.fromJson(Map<String, dynamic>.from(e as Map))).toList() ?? [];
      if (q.isEmpty) return;
      queue = q;
      index = (data['index'] as int?)?.clamp(0, q.length - 1) ?? 0;
      shuffle = data['shuffle'] as bool? ?? false;
      repeat = RepeatMode.values.firstWhere((e) => e.name == (data['repeat'] as String?), orElse: () => RepeatMode.off);
      notifyListeners();
    } catch (_) {}
  }

  final Ref _ref;
  late final bool _isAndroid;
  bool get isAndroid => _isAndroid;

  // Бэкенды — только один активен
  Player? _player;
  VideoController? videoController;
  AndroidPlayerBackend? _androidBackend;
  AndroidPlayerBackend? get androidBackend => _androidBackend;

  // Для UI — отдаём нативный VideoPlayer controller на Android
  vp.VideoPlayerController? get androidVideoController => _androidBackend?.controller;

  List<StreamSubscription<dynamic>> _subs = [];
  bool _queueRestored = false;

  LibraryController get _library => _ref.read(libraryProvider);
  SettingsController get _settings => _ref.read(settingsProvider);

  // Очередь
  List<MediaTrack> queue = [];
  int index = -1;
  bool shuffle = false;
  RepeatMode repeat = RepeatMode.off;
  final List<int> _history = [];
  final math.Random _rng = math.Random();

  // Состояние воспроизведения
  bool _playing = false;
  bool get isPlaying => _playing;

  bool _buffering = false;
  bool get isBuffering => _buffering;

  Duration _position = Duration.zero;
  Duration get position => _position;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  double _volume = 100;
  double get volume => _volume;
  double? _volumeBeforeMute;
  bool get muted => _volumeBeforeMute != null;

  double _rate = 1.0;
  double get rate => _rate;

  MediaTrack? get current =>
      (index >= 0 && index < queue.length) ? queue[index] : null;

  LrcLyrics? lyrics;
  bool get hasVideo => current?.isVideo ?? false;

  // Стримы для UI — унифицированы
  Stream<Duration> get positionStream =>
      _isAndroid ? _androidBackend!.positionStream : _player!.stream.position;
  Stream<bool> get bufferingStream => _isAndroid
      ? _androidBackend!.bufferingStream
      : _player!.stream.buffering;
  Stream<bool> get playingStream =>
      _isAndroid ? _androidBackend!.playingStream : _player!.stream.playing;

  // Дорожки — только на Desktop (libmpv)
  List<AudioTrack> get audioTracks =>
      _isAndroid ? const [] : _player!.state.tracks.audio;
  List<SubtitleTrack> get subtitleTracks =>
      _isAndroid ? const [] : _player!.state.tracks.subtitle;
  String? get selectedAudioTrackId =>
      _isAndroid ? null : _player!.state.track.audio?.id;
  String? get selectedSubtitleTrackId =>
      _isAndroid ? null : _player!.state.track.subtitle?.id;

  Future<void> selectAudioTrack(AudioTrack t) async {
    if (_isAndroid) return; // Media3: выбор дорожки через ExoPlayer — пока no-op
    await _player!.setAudioTrack(t);
    notifyListeners();
  }

  Future<void> selectSubtitleTrack(SubtitleTrack t) async {
    if (_isAndroid) return;
    await _player!.setSubtitleTrack(t);
    notifyListeners();
  }

  Future<void> selectSubtitleOff() async {
    if (_isAndroid) return;
    await _player!.setSubtitleTrack(SubtitleTrack.no());
    notifyListeners();
  }

  Future<void> loadExternalSubtitle(String path) async {
    if (_isAndroid) return; // на Android внешние субтитры — через PlayerView позже
    await _player!.setSubtitleTrack(
      SubtitleTrack.uri(path, title: 'Внешние субтитры'),
    );
    notifyListeners();
  }

  /// Виджет видео — адаптивный: Media3 SurfaceView на Android, libmpv на десктопе
  Widget buildVideoView({VideoFit fit = VideoFit.contain, bool fitCover = false}) {
    if (_isAndroid) {
      return _androidBackend!.buildVideoView(fit: fit, fitCover: fitCover);
    } else {
      final vc = videoController;
      if (vc == null) return const ColoredBox(color: Colors.black);
      // Desktop libmpv — используем нативный fit media_kit + доп. обёртку для 16:9/4:3
      BoxFit mkFit;
      switch (fit) {
        case VideoFit.contain: mkFit = BoxFit.contain; break;
        case VideoFit.cover: mkFit = BoxFit.cover; break;
        case VideoFit.stretch: mkFit = BoxFit.fill; break;
        case VideoFit.sixteenNine:
        case VideoFit.fourThree:
          mkFit = BoxFit.contain; break;
      }
      Widget video = ColoredBox(
        color: Colors.black,
        child: Video(
          controller: vc,
          fit: mkFit,
          controls: (state) => const SizedBox.shrink(),
        ),
      );
      if (fit == VideoFit.sixteenNine) {
        video = ColoredBox(color: Colors.black, child: Center(child: AspectRatio(aspectRatio: 16 / 9, child: video)));
      } else if (fit == VideoFit.fourThree) {
        video = ColoredBox(color: Colors.black, child: Center(child: AspectRatio(aspectRatio: 4 / 3, child: video)));
      }
      return video;
    }
  }

  // Фон — только для музыки: если система поставила паузу пока в бэкграунде — вернуть
  bool _inBackground = false;
  bool _wasPlayingMusicBeforeBg = false;
  void setBackground(bool bg) {
    _inBackground = bg;
    if (bg) {
      _wasPlayingMusicBeforeBg = isPlaying && current != null && !current!.isVideo;
      if (_wasPlayingMusicBeforeBg) {
        // страховка: через 300мс проверить не встала ли пауза из-за lifecycle
        Future.delayed(const Duration(milliseconds: 320), () async {
          if (_inBackground && _wasPlayingMusicBeforeBg && !_playing && current != null && !current!.isVideo) {
            try { await _backendPlay(); } catch (_) {}
          }
        });
      }
    } else {
      _wasPlayingMusicBeforeBg = false;
    }
  }
  void _maybeResumeMusicAfterSystemPause() {
    // вызывается когда playing: true -> false, проверяем что это системная пауза в фоне для музыки
    if (!_inBackground) return;
    if (!_wasPlayingMusicBeforeBg) return;
    final c = current;
    if (c == null || c.isVideo) return;
    // не в конце трека (осталось > 1с) — иначе это завершение
    if (_duration > Duration.zero && _position >= _duration - const Duration(seconds: 1)) return;
    Future.delayed(const Duration(milliseconds: 180), () async {
      if (_inBackground && _wasPlayingMusicBeforeBg && !_playing && current?.isVideo == false) {
        try { await _backendPlay(); } catch (_) {}
      }
    });
  }

  // Таймер сна
  Timer? _sleepTimer;
  DateTime? sleepEndsAt;
  bool get sleepActive => sleepEndsAt != null;

  // ---------- Открытие и очередь ----------

  Future<void> open(List<MediaTrack> tracks, int startIndex) async {
    if (tracks.isEmpty) return;
    _saveCurrentPosition();
    queue = List.of(tracks);
    index = startIndex.clamp(0, tracks.length - 1);
    _history.clear();
    _persistQueue();
    await _playCurrent();
  }

  Future<void> playAt(int i) async {
    if (i < 0 || i >= queue.length) return;
    _saveCurrentPosition();
    index = i;
    _persistQueue();
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    final t = current;
    if (t == null) return;
    _resumePending =
        _settings.restorePositions && _library.positionOf(t.path) > 10;
    lyrics = _loadLyrics(t);
    // Сбрасываем длительность до получения новой
    _duration = Duration.zero;
    _position = Duration.zero;
    notifyListeners();
    try {
      if (_isAndroid) {
        await _androidBackend!.open(t.path);
        _applyEq();
      } else {
        await _player!.open(Media(t.path));
        _applyEq();
      }
    } catch (e) {
      debugPrint('[Player] open failed ${t.path}: $e');
      // тихий фейл — не крашим приложение, переходим к следующему
      // чтобы не висеть на битом файле
      // Можно показать SnackBar на уровне UI, но тут не крашим
    }
  }

  LrcLyrics? _loadLyrics(MediaTrack t) {
    try {
      if (t.isVideo) return null;
      // content:// не имеет родительской папки — пропускаем
      if (t.path.startsWith('content://')) return null;
      final f = File(t.path);
      if (!f.existsSync()) return null;
      final dir = f.parent.path;
      final name = f.uri.pathSegments.last;
      final dot = name.lastIndexOf('.');
      final base = dot < 0 ? name : name.substring(0, dot);
      for (final candidate in ['$base.lrc', '$base.LRC']) {
        final lf = File('$dir${Platform.pathSeparator}$candidate');
        if (lf.existsSync()) {
          return LrcLyrics.parse(lf.readAsStringSync());
        }
      }
    } catch (_) {}
    return null;
  }

  void enqueue(List<MediaTrack> tracks) {
    queue = [...queue, ...tracks];
    _persistQueue();
    notifyListeners();
  }

  void removeFromQueue(int i) {
    if (i < 0 || i >= queue.length || i == index) return;
    queue.removeAt(i);
    if (i < index) index--;
    _persistQueue();
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= queue.length) return;
    final item = queue.removeAt(oldIndex);
    final idx = (newIndex > oldIndex ? newIndex - 1 : newIndex)
        .clamp(0, queue.length);
    queue.insert(idx, item);
    if (queue[idx].path == item.path) {
      index = idx;
    }
    _persistQueue();
    notifyListeners();
  }

  // ---------- Навигация ----------

  Future<void> next({bool manual = false}) async {
    if (queue.isEmpty) return;
    if (repeat == RepeatMode.one && !manual) {
      await _backendSeek(Duration.zero);
      await _backendPlay();
      return;
    }
    if (shuffle) {
      var i = _rng.nextInt(queue.length);
      if (queue.length > 1) {
        while (i == index) {
          i = _rng.nextInt(queue.length);
        }
      }
      _history.add(index);
      await playAt(i);
      return;
    }
    final n = index + 1;
    if (n < queue.length) {
      _history.add(index);
      await playAt(n);
    } else if (repeat == RepeatMode.all) {
      _history.add(index);
      await playAt(0);
    } else if (manual) {
      await _backendSeek(Duration.zero);
      await _backendPlay();
    }
  }

  Future<void> prev() async {
    if (queue.isEmpty) return;
    if (_position.inSeconds > 3 || _history.isEmpty) {
      await _backendSeek(Duration.zero);
      return;
    }
    await playAt(_history.removeLast());
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    _persistQueue();
    notifyListeners();
  }

  void cycleRepeat() {
    repeat = repeat == RepeatMode.off
        ? RepeatMode.all
        : repeat == RepeatMode.all
            ? RepeatMode.one
            : RepeatMode.off;
    _persistQueue();
    notifyListeners();
  }

  // ---------- Управление воспроизведением ----------

  Future<void> togglePlay() async {
    if (_isAndroid) {
      await _androidBackend!.playOrPause();
    } else {
      await _player!.playOrPause();
    }
  }

  Future<void> seek(Duration d) async {
    final clamped = d < Duration.zero
        ? Duration.zero
        : (_duration > Duration.zero && d > _duration ? _duration : d);
    await _backendSeek(clamped);
    notifyListeners();
  }

  Future<void> _backendSeek(Duration d) async {
    if (_isAndroid) {
      await _androidBackend!.seek(d);
    } else {
      await _player!.seek(d);
    }
  }

  Future<void> _backendPlay() async {
    if (_isAndroid) {
      await _androidBackend!.play();
    } else {
      await _player!.play();
    }
  }

  Future<void> _backendPause() async {
    if (_isAndroid) {
      await _androidBackend!.pause();
    } else {
      await _player!.pause();
    }
  }

  Future<void> pause() async => _backendPause();
  Future<void> play() async => _backendPlay();
  Future<void> pauseForStop() async {
    await _backendPause();
    notifyListeners();
  }

  Future<void> setVolume(double v) async {
    _volumeBeforeMute = null;
    _volume = v.clamp(0, 100);
    if (_isAndroid) {
      await _androidBackend!.setVolume(_volume);
    } else {
      await _player!.setVolume(_volume);
    }
    notifyListeners();
  }

  Future<void> toggleMute() async {
    if (_volumeBeforeMute == null) {
      _volumeBeforeMute = _volume;
      if (_isAndroid) {
        await _androidBackend!.setVolume(0);
      } else {
        await _player!.setVolume(0);
      }
      _volume = 0;
    } else {
      final v = _volumeBeforeMute!;
      _volumeBeforeMute = null;
      _volume = v;
      if (_isAndroid) {
        await _androidBackend!.setVolume(v);
      } else {
        await _player!.setVolume(v);
      }
    }
    notifyListeners();
  }

  Future<void> setRate(double r) async {
    final clamped = r.clamp(0.25, 2.0);
    _rate = clamped;
    if (_isAndroid) {
      await _androidBackend!.setRate(clamped);
    } else {
      await _player!.setRate(clamped);
    }
    notifyListeners();
  }

  // ---------- Потоки ----------

  int _lastSavedSec = -1;
  bool _resumePending = false;

  void _onPosition(Duration d) {
    _position = d;
    if (d.inSeconds != _lastSavedSec) {
      _lastSavedSec = d.inSeconds;
      notifyListeners();
      final t = current;
      if (t != null && _lastSavedSec % 5 == 0 && _duration > Duration.zero) {
        _library.savePosition(t.path, _lastSavedSec);
      }
    } else {
      // всё равно обновляем позицию для seekbar плавности, но без notify?
      // для видео нужен частый апдейт — но throttle раз в 250мс уже есть
    }
  }

  void _resolveResume() {
    if (!_resumePending || _duration <= Duration.zero) return;
    _resumePending = false;
    final t = current;
    if (t == null) return;
    final saved = _library.positionOf(t.path);
    final limitMs = _duration.inMilliseconds * 0.95;
    if (saved > 10 && saved * 1000 < limitMs) {
      _backendSeek(Duration(seconds: saved));
    }
  }

  void _updateDurationInLibrary() {
    final t = current;
    if (t != null && _duration > Duration.zero) {
      _library.updateDuration(t, _duration.inMilliseconds);
    }
  }

  void _saveCurrentPosition() {
    final t = current;
    if (t != null && _position.inSeconds > 5) {
      _library.savePosition(t.path, _position.inSeconds);
    }
  }

  // ---------- Эквалайзер ----------

  void applyEqualizer() {
    _applyEq();
  }

  void _applyEq() {
    final s = _settings;
    if (Platform.isAndroid) {
      NativeBridge.setEqEnabled(s.eqEnabled);
      NativeBridge.setEqGains(
        s.eqEnabled ? s.eqGains : List.filled(10, 0.0),
      );
      NativeBridge.setBassBoost(s.eqEnabled ? s.bassBoost : 0);
      return;
    }
    if (_player == null) return;
    final platform = _player!.platform;
    if (platform is! NativePlayer) return;
    try {
      if (!s.eqEnabled) {
        platform.setProperty('af', '');
        return;
      }
      final entries = <String>[];
      for (var i = 0; i < 10; i++) {
        final freq = eqFrequencies[i].toStringAsFixed(0);
        final g = s.eqGains[i].toStringAsFixed(1);
        entries.add('entry($freq,$g)');
      }
      entries.add('entry(20000,${s.eqGains[9].toStringAsFixed(1)})');
      final filter = "lavfi=[firequalizer=gain_entry='${entries.join(':')}']";
      platform.setProperty('af', filter);
    } catch (_) {}
  }

  // ---------- Таймер сна (с fade-out 15с как в Poweramp) ----------
  Timer? _sleepFadeTicker;

  void setSleepTimer(Duration? d) {
    _sleepTimer?.cancel();
    _sleepFadeTicker?.cancel();
    if (d == null) {
      sleepEndsAt = null;
      notifyListeners();
      return;
    }
    sleepEndsAt = DateTime.now().add(d);
    notifyListeners();
    _sleepTimer = Timer(d, () async {
      // Fade-out 15с: снижаем громкость ступенями
      final startVol = _volumeBeforeMute != null ? _volumeBeforeMute! : _volume;
      if (startVol <= 0) {
        await _backendPause();
        sleepEndsAt = null;
        notifyListeners();
        return;
      }
      const steps = 15;
      var step = 0;
      _sleepFadeTicker = Timer.periodic(const Duration(seconds: 1), (t) async {
        step++;
        final f = 1 - step / steps; // 0.93..0
        final v = (startVol * f).clamp(0, 100).toDouble();
        if (_isAndroid) {
          await _androidBackend?.setVolume(v);
        } else {
          await _player?.setVolume(v);
        }
        _volume = v;
        notifyListeners();
        if (step >= steps) {
          t.cancel();
          await _backendPause();
          // восстанавливаем громкость для следующего запуска
          _volume = startVol;
          if (_isAndroid) await _androidBackend?.setVolume(startVol);
          else await _player?.setVolume(startVol);
          sleepEndsAt = null;
          notifyListeners();
        }
      });
    });
  }

  // ---------- Жизненный цикл ----------

  @override
  void dispose() {
    _sleepTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    if (_isAndroid) {
      unawaited(_androidBackend!.dispose());
    } else {
      unawaited(_player!.dispose());
    }
    super.dispose();
  }
}

final playerProvider = ChangeNotifierProvider<PlayerController>((ref) {
  final c = PlayerController(ref);
  ref.onDispose(c.dispose);
  return c;
});
