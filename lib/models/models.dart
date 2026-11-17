import 'dart:io';

import 'package:flutter/foundation.dart';

const audioExtensions = [
  'mp3', 'wav', 'ogg', 'oga', 'm4a', 'aac', 'flac', 'opus', 'weba', 'wma',
  'ape', 'dsf',
];

const videoExtensions = [
  'mp4', 'webm', 'mkv', 'mov', 'avi', 'm4v', 'ogv', '3gp', 'ts', 'wmv',
  'flv', 'mpg', 'mpeg',
];

const streamExtensions = [
  'm3u8', 'mpd', 'm3u', 'm4s', 'fmp4', 'ism', 'isml',
];

String _ext(String p) {
  // Убираем query ?... и fragment #...
  final q = p.indexOf('?');
  final clean = q >= 0 ? p.substring(0, q) : p;
  final h = clean.indexOf('#');
  final c = h >= 0 ? clean.substring(0, h) : clean;
  final i = c.lastIndexOf('.');
  return i < 0 ? '' : c.substring(i + 1).toLowerCase();
}

bool isAudioPath(String p) => audioExtensions.contains(_ext(p));
bool isVideoPath(String p) => videoExtensions.contains(_ext(p)) || streamExtensions.contains(_ext(p));
bool isStreamUrl(String p) => p.startsWith('http://') || p.startsWith('https://') || p.startsWith('rtmp://') || p.startsWith('rtsp://');
bool isHls(String p) => _ext(p) == 'm3u8' || _ext(p) == 'm3u';
bool isDash(String p) => _ext(p) == 'mpd';
bool isFmp4(String p) => _ext(p) == 'm4s' || _ext(p) == 'fmp4';

@immutable
class MediaTrack {
  final String path;
  final bool isVideo;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final int sizeBytes;
  final int addedAt; // epoch ms

  const MediaTrack({
    required this.path,
    required this.isVideo,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.sizeBytes,
    required this.addedAt,
  });

  String get id => path;
  String get ext => _ext(path);

  factory MediaTrack.fromFile(
    File f, {
    required bool isVideo,
    String? title,
    String? artist,
    String? album,
  }) {
    final name = f.uri.pathSegments.isNotEmpty
        ? f.uri.pathSegments.last
        : f.path.split(Platform.pathSeparator).last;
    final dot = name.lastIndexOf('.');
    var t = (dot < 0 ? name : name.substring(0, dot))
        .replaceAll('_', ' ')
        .trim();
    var a = artist ?? '';
    if (a.isEmpty) {
      final dash = t.indexOf(' - ');
      if (dash > 0) {
        a = t.substring(0, dash).trim();
        t = t.substring(dash + 3).trim();
      }
    }
    return MediaTrack(
      path: f.path,
      isVideo: isVideo,
      title: title ?? (t.isEmpty ? name : t),
      artist: a,
      album: album ?? '',
      durationMs: 0,
      sizeBytes: f.lengthSync(),
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory MediaTrack.fromUrl(
    String url, {
    required bool isVideo,
    String? title,
  }) {
    final uri = Uri.tryParse(url);
    var name = title;
    if (name == null || name.isEmpty) {
      name = uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : url;
      if (name.isEmpty) name = url;
      // Убираем query
      final q = name.indexOf('?');
      if (q >= 0) name = name.substring(0, q);
      if (name.length > 60) name = name.substring(0, 60);
    }
    // Определяем тип по расширению или эвристике
    final e = _ext(url);
    final videoByExt = videoExtensions.contains(e) || streamExtensions.contains(e);
    return MediaTrack(
      path: url,
      isVideo: isVideo || videoByExt || isDash(url) || isHls(url),
      title: name!,
      artist: isStreamUrl(url) ? 'Поток' : '',
      album: '',
      durationMs: 0,
      sizeBytes: 0,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'isVideo': isVideo,
        'title': title,
        'artist': artist,
        'album': album,
        'durationMs': durationMs,
        'sizeBytes': sizeBytes,
        'addedAt': addedAt,
      };

  factory MediaTrack.fromJson(Map<String, dynamic> j) => MediaTrack(
        path: j['path'] as String,
        isVideo: j['isVideo'] as bool? ?? false,
        title: j['title'] as String? ?? '',
        artist: j['artist'] as String? ?? '',
        album: j['album'] as String? ?? '',
        durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
        sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
        addedAt: (j['addedAt'] as num?)?.toInt() ?? 0,
      );

  MediaTrack copyWith({
    String? title,
    String? artist,
    String? album,
    int? durationMs,
  }) {
    return MediaTrack(
      path: path,
      isVideo: isVideo,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationMs: durationMs ?? this.durationMs,
      sizeBytes: sizeBytes,
      addedAt: addedAt,
    );
  }
}

@immutable
class Playlist {
  final String id;
  final String name;
  final List<String> paths;

  const Playlist({
    required this.id,
    required this.name,
    required this.paths,
  });

  Playlist copyWith({String? name, List<String>? paths}) => Playlist(
        id: id,
        name: name ?? this.name,
        paths: paths ?? this.paths,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'paths': paths,
      };

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Без названия',
        paths: (j['paths'] as List?)?.cast<String>().toList() ?? <String>[],
      );
}

const eqFrequencies = <double>[
  32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000,
];

class EqPreset {
  final String key;
  final String label;
  final List<double> gains;

  const EqPreset(this.key, this.label, this.gains);
}

/// Те же пресеты, что и в веб-версии AURA.
const eqPresets = <EqPreset>[
  EqPreset('flat', 'Плоский', [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  EqPreset('bass', 'Бас+', [8, 7, 5, 2, 0, 0, 0, 0, 2, 3]),
  EqPreset('rock', 'Рок', [5, 4, 2, -1, -2, 1, 3, 5, 5, 4]),
  EqPreset('pop', 'Поп', [-1, 1, 3, 4, 4, 2, 0, -1, -1, 0]),
  EqPreset('jazz', 'Джаз', [4, 3, 1, 2, -1, -1, 0, 2, 3, 4]),
  EqPreset('classical', 'Классика', [3, 2, 0, 0, 0, -1, -1, 0, 2, 3]),
  EqPreset('vocal', 'Вокал', [-3, -2, 0, 3, 5, 5, 3, 1, -1, -2]),
  EqPreset('electronic', 'Электроника', [6, 5, 1, 0, -2, 2, 1, 3, 5, 6]),
];
