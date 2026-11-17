import 'dart:convert';
import 'dart:io';
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
  static const _vkClientIds = ['52461373', '51703666', '2274003'];
  static const _rutubeWdpTemplate = 'https://rutube.ru/api/play/options/%s/?client=wdp';
  static const _rutubeAndroidTemplate = 'https://rutube.ru/api/play/options/%s/?client=android';

  static String? _cachedVkToken;
  static int _vkTokenTs = 0;

  static bool isVkUrl(String u) =>
      u.contains('vk.com') || u.contains('vkvideo.ru') || u.contains('vk.ru') || u.contains('vk.me');
  static bool isRutubeUrl(String u) =>
      u.contains('rutube.ru') || u.contains('mediavitrina.ru') || u.contains('mvitrina');
  static bool isOkUrl(String u) => u.contains('ok.ru');

  static bool isDirectStream(String u) {
    final l = u.toLowerCase();
    return l.contains('.m3u8') || l.contains('.mpd') || l.contains('.m4s') ||
        l.startsWith('rtmp://') || l.startsWith('rtsp://') ||
        l.startsWith('http') && (l.contains('.mp4') || l.contains('.webm') || l.contains('.mkv'));
  }

  /// Общая точка входа — как resolvePlaybackSource в Kotlin.
  static Future<ResolvedStream?> resolve(String rawUrl) async {
    final url = rawUrl.trim();
    if (url.isEmpty) return null;
    if (isDirectStream(url)) {
      return ResolvedStream(videoId: 'direct_${url.hashCode}', masterUrl: url, isHls: url.contains('.m3u8'), headers: {'Accept':'*/*'});
    }
    if (isVkUrl(url)) return _resolveVk(url);
    if (isRutubeUrl(url)) return _resolveRutube(url);
    if (isOkUrl(url)) return _resolveOk(url);
    // fallback: попробовать как прямой
    if (url.startsWith('http')) return ResolvedStream(videoId: 'link_${url.hashCode}', masterUrl: url);
    return null;
  }

  // ---------- VK ----------
  static Future<String> _vkToken() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_cachedVkToken != null && now - _vkTokenTs < 3600*1000) return _cachedVkToken!;
    for (final cid in _vkClientIds) {
      try {
        final resp = await http.post(
          Uri.parse('https://login.vk.com/?act=get_anonym_token'),
          headers: {'User-Agent': _vkUA, 'Origin': 'https://vkvideo.ru', 'Referer': 'https://vkvideo.ru/', 'Content-Type': 'application/x-www-form-urlencoded'},
          body: 'client_id=$cid',
        ).timeout(const Duration(seconds: 8));
        if (!resp.statusCode.toString().startsWith('2')) continue;
        final j = jsonDecode(resp.body);
        final data = j['data'] ?? j['response'];
        final token = data?['access_token'] ?? j['access_token'] ?? '';
        if (token.toString().isNotEmpty) {
          _cachedVkToken = token; _vkTokenTs = now; return token;
        }
      } catch (_) {}
    }
    throw Exception('VK anonym token failed');
  }

  static Future<ResolvedStream?> _resolveVk(String url) async {
    try {
      // парсим owner_id/video_id
      final m = RegExp(r'(?:video|clip|vk_)(-?\d+)_(\d+)').firstMatch(url);
      if (m == null) {
        // попробуем как live.vkvideo.ru/@name
        final live = RegExp(r'live\.vkvideo\.ru/(?:app/)?([^/?#]+)').firstMatch(url);
        if (live != null) {
          final nick = live.group(1)!;
          return ResolvedStream(videoId: 'live_vk_$nick', masterUrl: url, isLive: true);
        }
        return null;
      }
      final owner = m.group(1)!;
      final vid = m.group(2)!;
      final ak = RegExp(r'access_key=([^&]+)').firstMatch(url)?.group(1);
      final token = await _vkToken();
      final param = ak != null ? '${owner}_${vid}_$ak' : '${owner}_${vid}';
      final resp = await http.post(
        Uri.parse('https://api.vk.com/method/video.get'),
        headers: {'User-Agent': _vkUA},
        body: {'v':'5.282','access_token': token, 'videos': param, 'extended':'1'},
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return _vkEmbedFallback(owner, vid, ak);
      final j = jsonDecode(resp.body);
      final items = (j['response']?['items'] as List?) ?? [];
      if (items.isEmpty) return _vkEmbedFallback(owner, vid, ak);
      final video = items.first as Map;
      final files = video['files'] as Map<String,dynamic>? ?? {};
      // ищем лучший HLS
      String? hls = files['hls_fmp4'] ?? files['hls'] ?? files['hls_live'] ?? files['live_fmp4'];
      if (hls == null) {
        for (final k in files.keys) { if (k.toString().contains('hls')) { hls = files[k].toString(); break; } }
      }
      if (hls == null || hls.isEmpty) return _vkEmbedFallback(owner, vid, ak);
      if (hls.startsWith('//')) hls = 'https:$hls';
      return ResolvedStream(
        videoId: 'vk_${owner}_$vid',
        masterUrl: hls,
        isLive: (video['is_live'] ?? 0) == 1 || (video['live_status'] ?? '') == 'started',
        headers: {'Referer':'https://vk.com/', 'Origin':'https://vk.com', 'User-Agent': _vkUA},
        pageUrl: url,
      );
    } catch (e) { return null; }
  }

  static Future<ResolvedStream?> _vkEmbedFallback(String owner, String vid, String? ak) async {
    try {
      final pageUrl = 'https://vk.com/video_ext.php?oid=$owner&id=$vid${ak!=null ? '&hash=$ak' : ''}';
      final resp = await http.get(Uri.parse(pageUrl), headers: {'User-Agent': _vkUA, 'Referer':'https://vk.com/'}).timeout(const Duration(seconds: 6));
      final html = resp.body;
      final m3 = RegExp(r'https?:[\\\/\w.\-~@%_+=#&?;:]+?\.m3u8[^\s"' + "'" + r'<>\\]*').firstMatch(html);
      if (m3 != null) {
        var u = m3.group(0)!.replaceAll(r'\/', '/').replaceAll(r'\u0026', '&');
        if (u.startsWith('//')) u = 'https:$u';
        return ResolvedStream(videoId: 'vk_${owner}_$vid', masterUrl: u, headers: {'Referer':'https://vk.com/'});
      }
    } catch (_) {}
    return null;
  }

  // ---------- Rutube ----------
  static Future<ResolvedStream?> _resolveRutube(String url) async {
    try {
      // вытаскиваем ID: rutube.ru/video/<id>/ или /video/<id>?...
      final idMatch = RegExp(r'rutube\.ru/(?:video|play)/([a-z0-9_-]+)', caseSensitive: false).firstMatch(url);
      final cleanId = idMatch?.group(1) ?? url.split('/').last.split('?').first;
      if (cleanId.isEmpty || cleanId.length > 64) return ResolvedStream(videoId: 'rutube_$cleanId', masterUrl: url);
      for (final tpl in [_rutubeWdpTemplate, _rutubeAndroidTemplate]) {
        try {
          final apiUrl = tpl.replaceFirst('%s', cleanId);
          final resp = await http.get(Uri.parse(apiUrl), headers: {'User-Agent': _vkUA, 'Referer':'https://rutube.ru/'}).timeout(const Duration(seconds: 6));
          if (resp.statusCode != 200) continue;
          final j = jsonDecode(resp.body);
          final streamUrl = j['video']?['m3u8'] ?? j['m3u8'] ?? j['streamUrl'] ?? j['video_balancer']?['m3u8'] ?? '';
          if (streamUrl.toString().isNotEmpty) {
            var m3u8 = streamUrl.toString();
            if (m3u8.startsWith('//')) m3u8 = 'https:$m3u8';
            final isLive = (j['is_live'] ?? false) == true || j.containsKey('live_streams');
            return ResolvedStream(videoId: 'rutube_$cleanId', masterUrl: m3u8, isLive: isLive, headers: {'Referer':'https://rutube.ru/', 'User-Agent': _vkUA}, pageUrl: url);
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
      // OK требует сложной подписи — отдаём как есть, Exo попробует прямую ссылку
      // Пользователь может вставить прямую .m3u8 из OK
      return ResolvedStream(videoId: 'ok_$id', masterUrl: url, headers: {'Referer':'https://ok.ru/'});
    } catch (_) { return null; }
  }
}
