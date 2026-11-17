import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/id3.dart';
import '../models/models.dart';
import 'native_bridge.dart';
import 'settings.dart';

/// Библиотека: треки, плейлисты, позиции воспроизведения, обложки.
/// Хранится в JSON-файлах в каталоге поддержки приложения.
class LibraryController extends ChangeNotifier {
  LibraryController(this._settings) {
    _settings.addListener(_onSettingsChanged);
  }

  final SettingsController _settings;

  List<MediaTrack> audio = [];
  List<MediaTrack> video = [];
  List<Playlist> playlists = [];
  final Map<String, int> positions = {}; // путь -> секунды

  bool scanning = false;
  double scanProgress = 0.0; // 0..1 для прогресс-бара
  int lastScanAdded = 0;
  int lastScanRemoved = 0;
  String? lastScanError;

  File? _libraryFile;
  File? _playlistsFile;
  File? _positionsFile;
  File? _queueFile;

  final Map<String, Uint8List?> _covers = {};
  final Set<String> _pendingCovers = {};

  void _onSettingsChanged() {
    // Настройки (акцент, тема и т.д.) не требуют реакции библиотеки:
    // пересканирование всегда явное — через scan().
  }

  Future<void> load() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final base = Directory(
        '${dir.path}${Platform.pathSeparator}aura',
      );
      if (!await base.exists()) await base.create(recursive: true);

      _libraryFile = File('${base.path}${Platform.pathSeparator}library.json');
      _playlistsFile =
          File('${base.path}${Platform.pathSeparator}playlists.json');
      _positionsFile =
          File('${base.path}${Platform.pathSeparator}positions.json');
      _queueFile = File('${base.path}${Platform.pathSeparator}queue.json');

      if (await _libraryFile!.exists()) {
        final list = (jsonDecode(await _libraryFile!.readAsString()) as List)
            .map((e) => MediaTrack.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        audio = list.where((t) => !t.isVideo).toList();
        video = list.where((t) => t.isVideo).toList();
      }
      if (await _playlistsFile!.exists()) {
        playlists = (jsonDecode(await _playlistsFile!.readAsString()) as List)
            .map((e) => Playlist.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      if (await _positionsFile!.exists()) {
        final raw =
            jsonDecode(await _positionsFile!.readAsString()) as Map<String, dynamic>;
        raw.forEach((k, v) => positions[k] = (v as num).toInt());
      }
      notifyListeners();
      _pruneMissing();
      // Автозапуск скана если библиотека пустая (первый запуск)
      if (audio.isEmpty && video.isEmpty && !scanning) {
        // Не делаем скан автоматически здесь — оставим это AppShell после проверки разрешений
        // Но на десктопе с настроенными папками можно попробовать
        if (!NativeBridge.isAndroid && _settings.scanDirs.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 500), () => scan());
        }
      }
    } catch (_) {
      // первая загрузка или недоступное хранилище
    }
  }

  // Явный автозапуск для Android после получения разрешений
  Future<void> ensureScanned() async {
    if (audio.isEmpty && video.isEmpty && !scanning) {
      await scan();
    }
  }

  Future<void> _persistLibrary() async {
    if (_libraryFile == null) return;
    try {
      await _libraryFile!.writeAsString(
        jsonEncode([...audio, ...video].map((t) => t.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _persistPlaylists() async {
    if (_playlistsFile == null) return;
    try {
      await _playlistsFile!
          .writeAsString(jsonEncode(playlists.map((p) => p.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> _persistPositions() async {
    if (_positionsFile == null) return;
    try {
      await _positionsFile!.writeAsString(jsonEncode(positions));
    } catch (_) {}
  }

  void _pruneMissing() {
    if (NativeBridge.isAndroid) return; // MediaStore сам следит за файлами
    final before = audio.length + video.length;
    audio = audio.where((t) => File(t.path).existsSync()).toList();
    video = video.where((t) => File(t.path).existsSync()).toList();
    if (audio.length + video.length != before) {
      _persistLibrary();
      notifyListeners();
    }
  }

  // ---------- Скан ----------

  bool _known(String path) =>
      audio.any((t) => t.path == path) || video.any((t) => t.path == path);

  Future<int> scan() async {
    if (scanning) return 0;
    scanning = true;
    scanProgress = 0.0;
    lastScanError = null;
    lastScanAdded = 0;
    lastScanRemoved = 0;
    notifyListeners();

    var added = 0;
    try {
      if (NativeBridge.isAndroid) {
        added = await _scanAndroid();
      } else {
        // Сканирование в изоляте чтобы не фризить UI на 10k файлов (P1)
        final dirs = _settings.scanDirs.where((d) => d.isNotEmpty).toList();
        if (dirs.isNotEmpty) {
          // Прогресс: 0.2 пока изолирован, 1.0 после
          scanProgress = 0.2;
          notifyListeners();
          final maps = await compute(_scanDirsIsolate, dirs);
          for (final m in maps) {
            final path = m['path'] as String;
            if (_known(path)) continue;
            final t = MediaTrack(
              path: path,
              isVideo: m['isVideo'] as bool,
              title: m['title'] as String,
              artist: m['artist'] as String,
              album: m['album'] as String,
              durationMs: 0,
              sizeBytes: m['sizeBytes'] as int? ?? 0,
              addedAt: m['addedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
            );
            if (t.isVideo) video.add(t); else audio.add(t);
            added++;
          }
          scanProgress = 0.8;
          notifyListeners();
          // Удаляем пропавшие файлы (как на Android)
          final before = audio.length + video.length;
          _pruneMissing();
          lastScanRemoved = before - (audio.length + video.length) - added;
          if (lastScanRemoved < 0) lastScanRemoved = 0;
        }
      }
      lastScanAdded = added;
      scanProgress = 1.0;
      notifyListeners();
      await _persistLibrary();
    } catch (e) {
      lastScanError = '$e';
    } finally {
      scanning = false;
      scanProgress = 0.0;
      notifyListeners();
    }
    return added;
  }

  Future<int> _scanAndroid() async {
    final items = await NativeBridge.scanMedia();
    var added = 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final scannedPaths = <String>{};
    for (final it in items) {
      final path = it['path'] as String?;
      if (path == null || path.isEmpty) continue;
      scannedPaths.add(path);
      if (_known(path)) continue;
      final isVideo = it['isVideo'] as bool? ?? false;
      final t = MediaTrack(
        path: path,
        isVideo: isVideo,
        title: (it['title'] as String?)?.isNotEmpty == true
            ? it['title'] as String
            : path,
        artist: (it['artist'] as String?) ?? '',
        album: (it['album'] as String?) ?? '',
        durationMs: (it['durationMs'] as num?)?.toInt() ?? 0,
        sizeBytes: (it['sizeBytes'] as num?)?.toInt() ?? 0,
        addedAt: (it['addedAt'] as num?)?.toInt() ?? now,
      );
      (isVideo ? video : audio).add(t);
      added++;
    }
    // Инкрементальный прун: удаляем то что есть в библиотеке но нет в MediaStore
    final before = audio.length + video.length;
    audio.removeWhere((t) => !scannedPaths.contains(t.path));
    video.removeWhere((t) => !scannedPaths.contains(t.path));
    lastScanRemoved = before - (audio.length + video.length) - added;
    if (lastScanRemoved < 0) lastScanRemoved = 0;
    if (lastScanRemoved > 0) await _persistLibrary();
    return added;
  }

  Future<int> _scanDirectory(Directory dir) async {
    if (!dir.existsSync()) return 0;
    final name = dir.path.split(Platform.pathSeparator).last;
    if (name.startsWith('.')) return 0;

    List<FileSystemEntity> entries;
    try {
      entries = await dir.list(followLinks: false).toList();
    } catch (_) {
      return 0;
    }

    var added = 0;
    for (final e in entries) {
      if (e is Directory) {
        added += await _scanDirectory(e);
        continue;
      }
      if (e is! File) continue;
      final p = e.path;
      final isAudio = isAudioPath(p);
      final isVideo = isVideoPath(p);
      if (!isAudio && !isVideo) continue;
      if (_known(p)) continue;

      var t = MediaTrack.fromFile(e, isVideo: isVideo);
      if (isAudio) {
        final tags = readId3Tags(p);
        if (tags != null) {
          t = t.copyWith(
            title: tags.title,
            artist: (tags.artist ?? '').isEmpty ? null : tags.artist,
            album: (tags.album ?? '').isEmpty ? null : tags.album,
          );
        }
      }
      (isVideo ? video : audio).add(t);
      added++;
    }
    return added;
  }

  // ---------- Обложки ----------

  Uint8List? coverOf(MediaTrack track) {
    if (track.isVideo) return null;
    final cached = _covers[track.path];
    if (cached != null) return cached;
    _loadCover(track);
    return null;
  }

  Future<void> _loadCover(MediaTrack track) async {
    if (_pendingCovers.contains(track.path)) return;
    _pendingCovers.add(track.path);
    try {
      Uint8List? bytes;
      if (NativeBridge.isAndroid) {
        bytes = await NativeBridge.albumArt(track.path);
      } else {
        final tags = readId3Tags(track.path);
        bytes = tags?.picture;
      }
      _covers[track.path] = bytes;
      notifyListeners();
    } catch (_) {
      _covers[track.path] = null;
    } finally {
      _pendingCovers.remove(track.path);
    }
  }

  // ---------- Треки ----------

  void updateDuration(MediaTrack track, int durationMs) {
    if (durationMs <= 0) return;
    final list = track.isVideo ? video : audio;
    final i = list.indexWhere((t) => t.path == track.path);
    if (i < 0) return;
    if (list[i].durationMs == durationMs) return;
    list[i] = list[i].copyWith(durationMs: durationMs);
    _persistLibrary();
    notifyListeners();
  }

  void importTrack(MediaTrack track) {
    if (_known(track.path)) return;
    if (track.isVideo) {
      video = [...video, track];
    } else {
      audio = [...audio, track];
    }
    _persistLibrary();
    notifyListeners();
  }

  void importTracks(List<MediaTrack> tracks) {
    var added = 0;
    for (final t in tracks) {
      if (_known(t.path)) continue;
      if (t.isVideo) video = [...video, t]; else audio = [...audio, t];
      added++;
    }
    if (added > 0) {
      _persistLibrary();
      notifyListeners();
    }
  }

  void removeTrack(MediaTrack track) {
    (track.isVideo ? video : audio).removeWhere((t) => t.path == track.path);
    _persistLibrary();
    notifyListeners();
  }

  void clearTracks(bool isVideo) {
    if (isVideo) {
      video = [];
    } else {
      audio = [];
    }
    _persistLibrary();
    notifyListeners();
  }

  void reorderTracks(bool isVideo, int oldIndex, int newIndex) {
    final list = isVideo ? video : audio;
    if (oldIndex < 0 || oldIndex >= list.length) return;
    final item = list.removeAt(oldIndex);
    final idx = (newIndex > oldIndex ? newIndex - 1 : newIndex)
        .clamp(0, list.length);
    list.insert(idx, item);
    _persistLibrary();
    notifyListeners();
  }

  // ---------- Плейлисты ----------

  void createPlaylist(String name) {
    playlists = [
      ...playlists,
      Playlist(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        paths: [],
      ),
    ];
    _persistPlaylists();
    notifyListeners();
  }

  void renamePlaylist(String id, String name) {
    playlists = playlists
        .map((p) => p.id == id ? p.copyWith(name: name) : p)
        .toList();
    _persistPlaylists();
    notifyListeners();
  }

  void deletePlaylist(String id) {
    playlists = playlists.where((p) => p.id != id).toList();
    _persistPlaylists();
    notifyListeners();
  }

  void addToPlaylist(String id, MediaTrack track) {
    playlists = playlists.map((p) {
      if (p.id != id || p.paths.contains(track.path)) return p;
      return p.copyWith(paths: [...p.paths, track.path]);
    }).toList();
    _persistPlaylists();
    notifyListeners();
  }

  void removeFromPlaylist(String id, String path) {
    playlists = playlists.map((p) {
      if (p.id != id) return p;
      return p.copyWith(paths: p.paths.where((x) => x != path).toList());
    }).toList();
    _persistPlaylists();
    notifyListeners();
  }

  void reorderPlaylist(String id, int oldIndex, int newIndex) {
    playlists = playlists.map((p) {
      if (p.id != id) return p;
      final list = List<String>.of(p.paths);
      if (oldIndex < 0 || oldIndex >= list.length) return p;
      final item = list.removeAt(oldIndex);
      final idx = (newIndex > oldIndex ? newIndex - 1 : newIndex)
          .clamp(0, list.length);
      list.insert(idx, item);
      return p.copyWith(paths: list);
    }).toList();
    _persistPlaylists();
    notifyListeners();
  }

  List<MediaTrack> tracksOfPlaylist(Playlist p) {
    final all = [...audio, ...video];
    final result = <MediaTrack>[];
    for (final path in p.paths) {
      for (final t in all) {
        if (t.path == path) {
          result.add(t);
          break;
        }
      }
    }
    return result;
  }

  // ---------- Позиции ----------

  int positionOf(String path) => positions[path] ?? 0;

  void savePosition(String path, int seconds) {
    if (seconds <= 0) return;
    positions[path] = seconds;
    _persistPositions();
  }

  void clearPositions() {
    positions.clear();
    _persistPositions();
    notifyListeners();
  }

  // ---------- Очередь (для восстановления после рестарта) ----------
  Future<void> saveQueue(List<MediaTrack> queue, int index, bool shuffle, String repeat) async {
    if (_queueFile == null) return;
    try {
      await _queueFile!.writeAsString(jsonEncode({
        'queue': queue.map((t) => t.toJson()).toList(),
        'index': index,
        'shuffle': shuffle,
        'repeat': repeat,
      }));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> loadQueue() async {
    if (_queueFile == null) return null;
    try {
      if (!await _queueFile!.exists()) return null;
      return jsonDecode(await _queueFile!.readAsString()) as Map<String, dynamic>;
    } catch (_) { return null; }
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }
}

/// Топ-уровневая функция для изолята — сканирует папки без блокировки UI
List<Map<String, dynamic>> _scanDirsIsolate(List<String> dirs) {
  final out = <Map<String, dynamic>>[];
  for (final d in dirs) {
    final dir = Directory(d);
    if (!dir.existsSync()) continue;
    _scanDirSync(dir, out);
  }
  return out;
}

void _scanDirSync(Directory dir, List<Map<String, dynamic>> out) {
  final name = dir.path.split(Platform.pathSeparator).last;
  if (name.startsWith('.')) return;
  List<FileSystemEntity> entries;
  try {
    entries = dir.listSync(followLinks: false);
  } catch (_) { return; }
  for (final e in entries) {
    if (e is Directory) {
      _scanDirSync(e, out);
      continue;
    }
    if (e is! File) continue;
    final p = e.path;
    final ext = p.split('.').last.toLowerCase();
    final isAudio = audioExtensions.contains(ext);
    final isVideo = videoExtensions.contains(ext);
    if (!isAudio && !isVideo) continue;
    try {
      final f = File(p);
      final stat = f.statSync();
      final seg = f.uri.pathSegments.isNotEmpty ? f.uri.pathSegments.last : p.split(Platform.pathSeparator).last;
      final dot = seg.lastIndexOf('.');
      var title = (dot < 0 ? seg : seg.substring(0, dot)).replaceAll('_', ' ').trim();
      String artist = '';
      final dash = title.indexOf(' - ');
      if (dash > 0) {
        artist = title.substring(0, dash).trim();
        title = title.substring(dash + 3).trim();
      }
      // ID3 в изоляте — пробуем, но не критично
      if (isAudio) {
        try {
          final tags = readId3Tags(p);
          if (tags != null) {
            if (tags.title?.isNotEmpty == true) title = tags.title!;
            if (tags.artist?.isNotEmpty == true) artist = tags.artist!;
          }
        } catch (_) {}
      }
      out.add({
        'path': p,
        'isVideo': isVideo,
        'title': title.isEmpty ? seg : title,
        'artist': artist,
        'album': '',
        'sizeBytes': stat.size,
        'addedAt': stat.modified.millisecondsSinceEpoch,
      });
    } catch (_) {}
  }
}

final libraryProvider = ChangeNotifierProvider<LibraryController>((ref) {
  final lib = LibraryController(ref.read(settingsProvider));
  ref.onDispose(lib.dispose);
  return lib;
});
