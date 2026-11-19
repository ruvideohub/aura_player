import 'dart:convert';
import 'package:http/http.dart' as http;

/// Результат резолва — как PlaybackSource в Kotlin.
class ResolvedStream {
  final String videoId;
  final String masterUrl;
  final bool isLive;
  final bool isHls;
  final Map<String, String> headers;
  final String? pageUrl;
  final List<String> alternateUrls;
  ResolvedStream({
    required this.videoId,
    required this.masterUrl,
    this.isLive = false,
    this.isHls = true,
    this.headers = const {},
    this.pageUrl,
    this.alternateUrls = const [],
  });
}

class StreamResolver {
  static const _vkUA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36';
  // полный список из VkVideoLoader.kt — рабочий набор
  static const _vkClientIds = ['52461373', '51703666', '2274003', '3140623', '6287487'];
  static const _rutubeWdpTemplate = 'https://rutube.ru/api/play/options/%s/?client=wdp';
  static const _rutubeAndroidTemplate = 'https://rutube.ru/api/play/options/%s/?client=android';
  static const _vkApiVersion = '5.282';

  static String? _cachedVkToken;
  static int _vkTokenTs = 0;
  static String? _workingClientId;

  static bool isVkUrl(String u) =>
      u.contains('vk.com') || u.contains('vkvideo.ru') || u.contains('vk.ru') || u.contains('vk.me');
  static bool isRutubeUrl(String u) =>
      u.contains('rutube.ru') || u.contains('mediavitrina.ru') || u.contains('mvitrina');
  static bool isOkUrl(String u) => u.contains('ok.ru');

  static bool isDirectStream(String u) {
    final l = u.toLowerCase();
    return l.contains('.m3u8') || l.contains('.mpd') || l.contains('.m4s') ||
        l.startsWith('rtmp://') ||
        l.startsWith('rtsp://') ||
        l.startsWith('http') && (l.contains('.mp4') || l.contains('.webm') || l.contains('.mkv'));
  }

  static Future<ResolvedStream?> resolve(String rawUrl) async {
    final url = rawUrl.trim();
    if (url.isEmpty) return null;
    if (isDirectStream(url)) {
      return ResolvedStream(videoId: 'direct_${url.hashCode}', masterUrl: url, isHls: url.contains('.m3u8'), headers: {'Accept': '*/*'});
    }
    if (isVkUrl(url)) return _resolveVk(url);
    if (isRutubeUrl(url)) return _resolveRutube(url);
    if (isOkUrl(url)) return _resolveOk(url);
    if (url.startsWith('http')) return ResolvedStream(videoId: 'link_${url.hashCode}', masterUrl: url);
    return null;
  }

  // ---------- VK токен (как в VkVideoLoader.getToken) ----------
  static Future<String> _vkToken() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_cachedVkToken != null && now - _vkTokenTs < 3600 * 1000) return _cachedVkToken!;
    final defaultIds = _vkClientIds;
    final ids = _workingClientId != null ? [_workingClientId!, ...defaultIds.where((e) => e != _workingClientId)] : defaultIds;
    Exception? lastEx;
    for (final cid in ids) {
      try {
        final resp = await http.post(
          Uri.parse('https://login.vk.com/?act=get_anonym_token'),
          headers: {'User-Agent': _vkUA, 'Origin': 'https://vkvideo.ru', 'Referer': 'https://vkvideo.ru/', 'Content-Type': 'application/x-www-form-urlencoded'},
          body: 'client_id=$cid',
        ).timeout(const Duration(seconds: 8));
        if (resp.statusCode < 200 || resp.statusCode >= 300) continue;
        final j = jsonDecode(resp.body);
        if (j is! Map) continue;
        // проверяем type == okay как в Kotlin
        final type = j['type']?.toString();
        if (type != null && type != 'okay') continue;
        final data = (j['data'] ?? j['response']) as Map?;
        final token = data?['access_token']?.toString() ?? j['access_token']?.toString() ?? '';
        if (token.isNotEmpty) {
          _cachedVkToken = token;
          _vkTokenTs = now;
          _workingClientId = cid;
          return token;
        }
      } catch (e) {
        lastEx = e is Exception ? e : Exception(e.toString());
      }
    }
    if (_cachedVkToken != null) return _cachedVkToken!;
    throw lastEx ?? Exception('VK anonym token failed for ${ids.join(",")}');
  }

  // Парсинг owner/vid/access_key — копия VkVideoLoader.parseVideoUrl + VkVideoParser.extractVkVideoParams
  static _VkParsed? _parseVideoUrl(String url) {
    final clean = url.trim();
    final pathPattern = RegExp(r'(?:video|clip|videos|clips|vk_)(-?\d+)_(\d+)(?:_([a-zA-Z0-9_-]+))?');
    final m = pathPattern.firstMatch(clean);
    if (m != null) {
      var ak = m.group(3);
      if (ak == null || ak.isEmpty) {
        ak = RegExp(r'access_key=([^&]+)').firstMatch(clean)?.group(1);
      }
      return _VkParsed(m.group(1)!, m.group(2)!, ak);
    }
    final q = RegExp(r'oid=(-?\d+)&id=(\d+)').firstMatch(clean);
    if (q != null) {
      final ak = RegExp(r'access_key=([^&]+)').firstMatch(clean)?.group(1) ??
          RegExp(r'hash=([^&]+)').firstMatch(clean)?.group(1);
      return _VkParsed(q.group(1)!, q.group(2)!, ak);
    }
    // fallback: отдельные query param
    String? oid = RegExp(r'[?&]oid=([^&#]+)').firstMatch(clean)?.group(1) ?? RegExp(r'[?&]owner_id=([^&#]+)').firstMatch(clean)?.group(1);
    String? vid = RegExp(r'[?&]id=([^&#]+)').firstMatch(clean)?.group(1) ?? RegExp(r'[?&]video_id=([^&#]+)').firstMatch(clean)?.group(1);
    if (oid != null && vid != null) {
      final ak = RegExp(r'access_key=([^&]+)').firstMatch(clean)?.group(1) ?? RegExp(r'hash=([^&]+)').firstMatch(clean)?.group(1);
      return _VkParsed(oid, vid, ak);
    }
    return null;
  }

  static String _unescape(String s) => s.replaceAll(r'\/', '/').replaceAll(r'\u0026', '&').replaceAll('&amp;', '&').replaceAll('&#38;', '&');
  static String _normUrl(String raw) {
    var u = _unescape(raw.trim());
    if (u.startsWith('//')) u = 'https:$u';
    return u;
  }

  // ---------- VK резолв ----------
  static Future<ResolvedStream?> _resolveVk(String url) async {
    try {
      // live
      final live = RegExp(r'live\.vkvideo\.ru/(?:app/)?([^/?#]+)').firstMatch(url) ??
          RegExp(r'live\.vkplay\.ru/(?:app/)?([^/?#]+)').firstMatch(url);
      if (live != null) {
        final nick = live.group(1)!;
        if (!['app', 'login', 'category', 'categories', 'games', 'stream'].contains(nick)) {
          return ResolvedStream(videoId: 'live_vk_$nick', masterUrl: url, isLive: true);
        }
      }
      final parsed = _parseVideoUrl(url);
      if (parsed == null) {
        // пробуем как общий VK парсер (al_video fallback)
        final al = await _fetchFromAlVideoFallback(url);
        if (al != null) return al;
        return null;
      }
      final owner = parsed.owner;
      final vid = parsed.id;
      final ak = parsed.accessKey;

      // 1) Пробуем VK API video.get
      try {
        final token = await _vkToken();
        final param = ak != null && ak.isNotEmpty ? '${owner}_${vid}_$ak' : '${owner}_${vid}';
        final resp = await http.post(
          Uri.parse('https://api.vk.com/method/video.get'),
          headers: {'User-Agent': _vkUA, 'Origin': 'https://vkvideo.ru', 'Referer': 'https://vkvideo.ru/'},
          body: {'v': _vkApiVersion, 'access_token': token, 'videos': param, 'extended': '1'},
        ).timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final j = jsonDecode(resp.body);
          if (j is Map && j['error'] == null) {
            final items = (j['response']?['items'] as List?) ?? [];
            if (items.isNotEmpty) {
              final video = items.first as Map;
              final files = video['files'] as Map<String, dynamic>? ?? {};
              final urls = <String, String>{};
              for (final e in files.entries) {
                if (e.value is String) urls[e.key] = e.value as String;
              }
              // audio tracks тоже могут содержать hls
              final extraAudios = (video['audioTracks'] as List?) ?? (video['audios'] as List?) ?? (video['tracks'] as List?) ?? [];
              for (final t in extraAudios) {
                if (t is Map) {
                  final u = (t['url'] ?? t['hls'] ?? t['src'])?.toString() ?? '';
                  if (u.isNotEmpty) urls['audio_${urls.length}'] = u;
                }
              }
              final filesAudio = (files['audioTracks'] as List?) ?? [];
              for (final t in filesAudio) {
                if (t is Map) {
                  final u = (t['url'] ?? t['hls'] ?? t['src'])?.toString() ?? '';
                  if (u.isNotEmpty) urls['audio_${urls.length}'] = u;
                }
              }
              final picked = _pickHlsFromFiles(urls, video);
              if (picked != null) {
                return ResolvedStream(
                  videoId: 'vk_${owner}_$vid',
                  masterUrl: picked,
                  isLive: (video['is_live'] ?? 0) == 1 || (video['live_status'] ?? '') == 'started' || (video['live_status'] ?? '') == 'in_progress',
                  headers: {'Referer': 'https://vk.com/', 'Origin': 'https://vk.com', 'User-Agent': _vkUA},
                  pageUrl: url,
                );
              }
            }
          }
        }
      } catch (_) {}

      // 2) embed скрап + al_video
      final embed = await _scrapeEmbedVariants(owner, vid, ak);
      if (embed != null) return embed;

      final al = await _tryAlVideo(owner, vid, ak, url);
      if (al != null) return al;

      return null;
    } catch (_) {
      return null;
    }
  }

  static String? _pickHlsFromFiles(Map<String, String> files, Map video) {
    // приоритет fmp4 как в Kotlin
    final isLive = (video['is_live'] ?? 0) == 1 || (video['live_status'] ?? '') == 'started';
    String? norm(String? s) {
      if (s == null || s.isEmpty) return null;
      var u = _normUrl(s);
      return u;
    }
    // 1) hls_fmp4 family
    for (final k in ['hls_fmp4', 'hls_fmp4_live', 'live_fmp4', 'fmp4_hls', 'fmp4']) {
      final v = norm(files[k]);
      if (v != null) return v;
    }
    // 1.1 конкрентные качества fmp4
    for (final k in ['hls_fmp4_2160', 'hls_fmp4_1440', 'hls_fmp4_1080', 'hls_fmp4_720', 'hls_fmp4_480', 'hls_fmp4_360']) {
      final v = norm(files[k]);
      if (v != null) return v;
    }
    // 1.2 ts hls
    for (final k in ['hls', 'hls_live', 'live_hls', 'live', 'live_playback', 'live_url']) {
      final v = norm(files[k]);
      if (v != null) return v;
    }
    // any hls
    for (final e in files.entries) {
      if (e.key.contains('hls') || e.value.contains('.m3u8')) {
        final v = norm(e.value);
        if (v != null) return v;
      }
    }
    if (isLive) {
      for (final e in files.entries) {
        final v = norm(e.value);
        if (v != null && v.contains('live')) return v;
      }
    }
    // dash/mp4 last resort — но для Exo нужен HLS, вернём mp4 если есть
    for (final e in files.entries) {
      if (e.key.startsWith('mp4_') || e.key.contains('hd')) {
        final v = norm(e.value);
        if (v != null) return v;
      }
    }
    final mp4 = norm(files['mp4']);
    if (mp4 != null) return mp4;
    return null;
  }

  // ---------- al_video.php (самый надёжный как в VkVideoParser.fetchFromAlVideo) ----------
  static Future<ResolvedStream?> _tryAlVideo(String owner, String vid, String? ak, String originalUrl) async {
    for (final endpoint in ['https://vk.com/al_video.php', 'https://vkvideo.ru/al_video.php']) {
      try {
        final videoParam = (ak != null && ak.isNotEmpty) ? '${owner}_${vid}_$ak' : '${owner}_${vid}';
        final body = <String, String>{'act': 'show', 'al': '1', 'video': videoParam};
        if (ak != null && ak.isNotEmpty) {
          body['hash'] = ak;
          body['list'] = ak;
        }
        final origin = endpoint.contains('vkvideo.ru') ? 'https://vkvideo.ru' : 'https://vk.com';
        final resp = await http.post(
          Uri.parse(endpoint),
          headers: {'User-Agent': _vkUA, 'X-Requested-With': 'XMLHttpRequest', 'Referer': '$origin/', 'Origin': origin, 'Content-Type': 'application/x-www-form-urlencoded'},
          body: body,
        ).timeout(const Duration(seconds: 8));
        if (resp.statusCode != 200) continue;
        final rs = _extractVariantsFromBody(resp.body);
        if (rs != null && rs.isNotEmpty) {
          final best = _chooseBestVariant(rs);
          if (best != null) {
            return ResolvedStream(videoId: 'vk_${owner}_$vid', masterUrl: best, isLive: best.contains('live.m3u8'), headers: {'Referer': 'https://vk.com/', 'User-Agent': _vkUA}, pageUrl: originalUrl);
          }
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<ResolvedStream?> _fetchFromAlVideoFallback(String url) async {
    // когда нет parsed owner/vid — пытаемся напрямую через Парсер
    try {
      final parsed = _parseVideoUrl(url);
      if (parsed == null) return null;
      return await _tryAlVideo(parsed.owner, parsed.id, parsed.accessKey, url);
    } catch (_) {
      return null;
    }
  }

  // ---------- embed scraping (video_ext.php) ----------
  static Future<ResolvedStream?> _scrapeEmbedVariants(String owner, String vid, String? ak) async {
    final pageUrls = [
      'https://vk.com/video_ext.php?oid=$owner&id=$vid${ak != null && ak.isNotEmpty ? '&hash=$ak' : ''}',
      'https://vkvideo.ru/video_ext.php?oid=$owner&id=$vid${ak != null && ak.isNotEmpty ? '&hash=$ak' : ''}',
      'https://vkvideo.ru/video${owner}_${vid}${ak != null && ak.isNotEmpty ? '?access_key=$ak' : ''}',
    ];
    for (final pageUrl in pageUrls) {
      try {
        final resp = await http.get(Uri.parse(pageUrl), headers: {'User-Agent': _vkUA, 'Referer': 'https://vk.com/', 'Origin': 'https://vkvideo.ru'}).timeout(const Duration(seconds: 6));
        if (resp.statusCode != 200) continue;
        final body = resp.body;
        final vars = _extractVariantsFromBody(body);
        if (vars != null && vars.isNotEmpty) {
          final best = _chooseBestVariant(vars);
          if (best != null) {
            return ResolvedStream(videoId: 'vk_${owner}_$vid', masterUrl: best, headers: {'Referer': 'https://vk.com/', 'User-Agent': _vkUA}, pageUrl: pageUrl);
          }
        }
        // fallback m3u8 regex напрямую
        final m3 = RegExp(r'https?:[\\\/\w.\-~@%_+=#&?;:]+?\.m3u8[^\s"''<>\\]*').firstMatch(body);
        if (m3 != null) {
          var u = _normUrl(m3.group(0)!);
          return ResolvedStream(videoId: 'vk_${owner}_$vid', masterUrl: u, headers: {'Referer': 'https://vk.com/', 'User-Agent': _vkUA});
        }
      } catch (_) {}
    }
    return null;
  }

  static List<String>? _extractVariantsFromBody(String body) {
    final normalized = body.replaceAll(r'\"', '"').replaceAll(r'\/', '/').replaceAll(r'\u0026', '&').replaceAll('&amp;', '&');
    final out = <String>[];
    void addIf(String? raw) {
      if (raw == null || raw.isEmpty) return;
      final u = _normUrl(raw);
      if (u.contains('.m3u8') || u.contains('.mpd') || u.contains('.mp4') || u.contains('hls') || u.contains('fmp4')) {
        if (!out.contains(u)) out.add(u);
      }
    }
    // 1) hls_fmp4 / fmp4
    final fmp4Re = RegExp(r'''(?:["']hls_fmp4["']|["']fmp4["']|fmp4)\s*:\s*["']([^"']+)["']''');
    final fmp4 = fmp4Re.firstMatch(normalized)?.group(1) ?? fmp4Re.firstMatch(body)?.group(1);
    addIf(fmp4);
    // 2) hls ts
    final hlsRe = RegExp(r'''(?:["']hls["']|hls)\s*:\s*["']([^"']+)["']''');
    final hls = hlsRe.firstMatch(normalized)?.group(1) ?? hlsRe.firstMatch(body)?.group(1);
    addIf(hls);
    // 3) url1080 etc
    for (final k in ['url2160', 'url1440', 'url1080', 'url720', 'url480', 'url360', 'url240']) {
      final re = RegExp('(?:["\']$k["\']|$k)\\s*:\\s*["\']([^"\']+)["\']');
      final m = re.firstMatch(normalized)?.group(1) ?? re.firstMatch(body)?.group(1);
      addIf(m);
    }
    // 4) dash
    final dashRe = RegExp(r'''(?:["'](?:dash_fmp4|dash|mpd)["']|dash_fmp4)\s*:\s*["']([^"']+)["']''');
    final dash = dashRe.firstMatch(normalized)?.group(1) ?? dashRe.firstMatch(body)?.group(1);
    addIf(dash);
    // 5) любые m3u8/mp4 в тексте
    final m3u8Re = RegExp(r'''https?:[\\\/\w.\-~@%_+=#&?;:]+?\.m3u8[^\s"'<>\\]*''');
    for (final m in m3u8Re.allMatches(normalized)) {
      addIf(m.group(0));
    }
    for (final m in m3u8Re.allMatches(body)) {
      addIf(m.group(0));
    }
    final mp4Re = RegExp(r'''https?:[\\\/\w.\-~@%_+=#&?;:]+?\.mp4[^\s"'<>\\]*''');
    for (final m in mp4Re.allMatches(normalized)) {
      addIf(m.group(0));
    }
    return out.isEmpty ? null : out;
  }

  static String? _chooseBestVariant(List<String> vars) {
    // приоритет fmp4
    for (final v in vars) {
      if (v.contains('fmp4')) return v;
    }
    for (final v in vars) {
      if (v.contains('.m3u8')) return v;
    }
    if (vars.isNotEmpty) return vars.first;
    return null;
  }

  // ---------- Rutube ----------
  static Future<ResolvedStream?> _resolveRutube(String url) async {
    try {
      final idMatch = RegExp(r'rutube\.ru/(?:video|play)/([a-z0-9_-]+)', caseSensitive: false).firstMatch(url);
      final cleanId = idMatch?.group(1) ?? url.split('/').last.split('?').first;
      if (cleanId.isEmpty || cleanId.length > 64) return ResolvedStream(videoId: 'rutube_$cleanId', masterUrl: url);
      for (final tpl in [_rutubeWdpTemplate, _rutubeAndroidTemplate]) {
        try {
          final apiUrl = tpl.replaceFirst('%s', cleanId);
          final resp = await http.get(Uri.parse(apiUrl), headers: {'User-Agent': _vkUA, 'Referer': 'https://rutube.ru/'}).timeout(const Duration(seconds: 6));
          if (resp.statusCode != 200) continue;
          final j = jsonDecode(resp.body);
          final streamUrl = j['video']?['m3u8'] ?? j['m3u8'] ?? j['streamUrl'] ?? j['video_balancer']?['m3u8'] ?? '';
          if (streamUrl.toString().isNotEmpty) {
            var m3u8 = streamUrl.toString();
            if (m3u8.startsWith('//')) m3u8 = 'https:$m3u8';
            final isLive = (j['is_live'] ?? false) == true || j.containsKey('live_streams');
            return ResolvedStream(videoId: 'rutube_$cleanId', masterUrl: m3u8, isLive: isLive, headers: {'Referer': 'https://rutube.ru/', 'User-Agent': _vkUA}, pageUrl: url);
          }
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }

  // ---------- OK ----------
  static Future<ResolvedStream?> _resolveOk(String url) async {
    try {
      final id = RegExp(r'ok\.ru/video/(\d+)').firstMatch(url)?.group(1);
      if (id == null) return null;
      return ResolvedStream(videoId: 'ok_$id', masterUrl: url, headers: {'Referer': 'https://ok.ru/'});
    } catch (_) {
      return null;
    }
  }
}

class _VkParsed {
  final String owner;
  final String id;
  final String? accessKey;
  _VkParsed(this.owner, this.id, this.accessKey);
}
