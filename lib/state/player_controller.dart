import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../core/lrc.dart';
import '../models/models.dart';
import '../services/library.dart';
import '../services/native_bridge.dart';
import '../services/settings.dart';

/// Центральный контроллер плеера: очередь, шаффл, повтор,
/// восстановление позиции, эквалайзер, таймер сна.
class PlayerController extends ChangeNotifier {
  PlayerController(this._ref) {
    final player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 64 * 1024 * 1024,
      ),
    );
    _player = player;
    videoController = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    _subs = [
      player.stream.playing.listen((v) {
        _playing = v;
        notifyListeners();
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
    ];
  }

  final Ref _ref;
  late final Player _player;
  late final VideoController videoController;
  List<StreamSubscription<dynamic>> _subs = [];

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

  // Публичный доступ к стримам и дорожкам libmpv для UI
  Stream<Duration> get positionStream => _player.stream.position;
  Stream<bool> get bufferingStream => _player.stream.buffering;
  Stream<bool> get playingStream => _player.stream.playing;

  List<AudioTrack> get audioTracks => _player.state.tracks.audio;
  List<SubtitleTrack> get subtitleTracks => _player.state.tracks.subtitle;
  String? get selectedAudioTrackId => _player.state.track.audio?.id;
  String? get selectedSubtitleTrackId => _player.state.track.subtitle?.id;

  Future<void> selectAudioTrack(AudioTrack t) async {
    await _player.setAudioTrack(t);
    notifyListeners();
  }

  Future<void> selectSubtitleTrack(SubtitleTrack t) async {
    await _player.setSubtitleTrack(t);
    notifyListeners();
  }

  Future<void> selectSubtitleOff() async {
    await _player.setSubtitleTrack(SubtitleTrack.no());
    notifyListeners();
  }

  Future<void> loadExternalSubtitle(String path) async {
    await _player.setSubtitleTrack(
      SubtitleTrack.uri(path, title: 'Внешние субтитры'),
    );
    notifyListeners();
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
    await _playCurrent();
  }

  Future<void> playAt(int i) async {
    if (i < 0 || i >= queue.length) return;
    _saveCurrentPosition();
    index = i;
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    final t = current;
    if (t == null) return;
    _resumePending =
        _settings.restorePositions && _library.positionOf(t.path) > 10;
    lyrics = _loadLyrics(t);
    notifyListeners();
    try {
      await _player.open(Media(t.path));
      _applyEq();
    } catch (_) {}
  }

  LrcLyrics? _loadLyrics(MediaTrack t) {
    try {
      if (t.isVideo) return null;
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
    notifyListeners();
  }

  void removeFromQueue(int i) {
    if (i < 0 || i >= queue.length || i == index) return;
    queue.removeAt(i);
    if (i < index) index--;
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
    notifyListeners();
  }

  // ---------- Навигация ----------

  Future<void> next({bool manual = false}) async {
    if (queue.isEmpty) return;
    if (repeat == RepeatMode.one && !manual) {
      await _player.seek(Duration.zero);
      await _player.play();
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
      await _player.seek(Duration.zero);
      await _player.play();
    }
  }

  Future<void> prev() async {
    if (queue.isEmpty) return;
    if (_position.inSeconds > 3 || _history.isEmpty) {
      await _player.seek(Duration.zero);
      return;
    }
    await playAt(_history.removeLast());
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    notifyListeners();
  }

  void cycleRepeat() {
    repeat = repeat == RepeatMode.off
        ? RepeatMode.all
        : repeat == RepeatMode.all
            ? RepeatMode.one
            : RepeatMode.off;
    notifyListeners();
  }

  // ---------- Управление воспроизведением ----------

  Future<void> togglePlay() async {
    await _player.playOrPause();
  }

  Future<void> seek(Duration d) async {
    final clamped = d < Duration.zero
        ? Duration.zero
        : (_duration > Duration.zero && d > _duration ? _duration : d);
    await _player.seek(clamped);
    notifyListeners();
  }

  Future<void> setVolume(double v) async {
    _volumeBeforeMute = null;
    await _player.setVolume(v.clamp(0, 100));
  }

  Future<void> toggleMute() async {
    if (_volumeBeforeMute == null) {
      _volumeBeforeMute = _volume;
      await _player.setVolume(0);
    } else {
      final v = _volumeBeforeMute!;
      _volumeBeforeMute = null;
      await _player.setVolume(v);
    }
    notifyListeners();
  }

  Future<void> setRate(double r) async {
    await _player.setRate(r.clamp(0.25, 2.0));
    notifyListeners();
  }

  // ---------- Потоки ----------

  int _lastSavedSec = -1;
  bool _resumePending = false;

  void _onPosition(Duration d) {
    _position = d;
    // Уведомляем раз в секунду, чтобы не перестраивать UI 60 раз в секунду
    if (d.inSeconds != _lastSavedSec) {
      _lastSavedSec = d.inSeconds;
      notifyListeners();
      final t = current;
      if (t != null &&
          _lastSavedSec % 5 == 0 &&
          _duration > Duration.zero) {
        _library.savePosition(t.path, _lastSavedSec);
      }
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
      _player.seek(Duration(seconds: saved));
    }
  }

  void _updateDurationInLibrary() {
    final t = current;
    if (t != null && _duration > Duration.zero) {
      _library.updateDuration(t, _duration.inMilliseconds);
    }
  }

  void _onCompleted() {
    next(manual: false);
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
    if (NativeBridge.isAndroid) {
      NativeBridge.setEqEnabled(s.eqEnabled);
      NativeBridge.setEqGains(
        s.eqEnabled ? s.eqGains : List.filled(10, 0.0),
      );
      return;
    }
    final platform = _player.platform;
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
      entries
          .add('entry(20000,${s.eqGains[9].toStringAsFixed(1)})');
      final filter =
          "lavfi=[firequalizer=gain_entry='${entries.join(':')}']";
      platform.setProperty('af', filter);
    } catch (_) {
      // фильтр может не поддерживаться — молча игнорируем
    }
  }

  // ---------- Таймер сна ----------

  void setSleepTimer(Duration? d) {
    _sleepTimer?.cancel();
    if (d == null) {
      sleepEndsAt = null;
      notifyListeners();
      return;
    }
    sleepEndsAt = DateTime.now().add(d);
    _sleepTimer = Timer(d, () async {
      await _player.pause();
      sleepEndsAt = null;
      notifyListeners();
    });
    notifyListeners();
  }

  // ---------- Жизненный цикл ----------

  @override
  void dispose() {
    _sleepTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    unawaited(_player.dispose());
    super.dispose();
  }
}

final playerProvider = ChangeNotifierProvider<PlayerController>((ref) {
  final c = PlayerController(ref);
  ref.onDispose(c.dispose);
  return c;
});
