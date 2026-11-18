import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Чистый VkApi — без мусора, только то что нужно для видео + музыки.
/// Авторизация — как сайт vk.ru через vkvideoapp.
class VkApi {
  static const hostApi = 'https://api.vk.com';
  static const hostApiRu = 'https://api.vk.ru';
  static const hostCatalog = 'https://api.vkvideo.ru';
  static const hostLogin = 'https://login.vk.com/?act=get_anonym_token';
  static const oauthRedirectUri = 'https://oauth.vk.ru/blank.html';
  static const hostOAuthAuthorize = 'https://oauth.vk.com/authorize';

  // Сайт vk.ru — как в твоём vk.zip, только клиент как у сайта
  static const v = '5.289'; // как в queue.subscribe?v=5.289
  static const vFallback = '5.131';
  static const hostSiteApi = 'https://web.api.vk.ru';

  // vk.ru web клиент из queue.subscribe — ты вытащил 7879029
  static const oauthClientId = '7879029';
  static const oauthScope = 'audio,video,offline,friends,groups,wall';

  static const List<String> clientIds = [
    '7879029', // сайт vk.ru web — primary как просил
    '52461373',
    '51703666',
    '51858169',
    '2274003',
  ];

  // Методы
  static const _videoSearch = 'video.search';
  static const _catalogVideoSearchWeb2 = 'catalog.getVideoSearchWeb2';
  static const _videoGet = 'video.get';

  static String _urlEncode(String s) => Uri.encodeComponent(s);

  static String call({
    required String host,
    required String name,
    String? token,
    String version = v,
    Map<String, String> params = const {},
  }) {
    final sb = StringBuffer('$host/method/$name?v=$version');
    if (token != null && token.isNotEmpty) sb.write('&access_token=${_urlEncode(token)}');
    for (final e in params.entries) sb.write('&${e.key}=${_urlEncode(e.value)}');
    return sb.toString();
  }

  static String videoSearch({required String token, required String query, int count = 30, int offset = 0}) =>
      call(host: hostApi, name: _videoSearch, token: token, params: {'q': query, 'count': '$count', 'offset': '$offset', 'extended': '1'});

  static String videoGet({required String token, int? ownerId, String? videos, int count = 20, int offset = 0}) => call(
      host: hostApi,
      name: _videoGet,
      token: token,
      params: {if (ownerId != null) 'owner_id': '$ownerId', if (videos != null) 'videos': videos, 'count': '$count', 'offset': '$offset', 'extended': '1'});

  static String catalogVideoSearchWeb2({required String token, required String clientId, required String query, int count = 30}) =>
      call(host: hostCatalog, name: _catalogVideoSearchWeb2, token: token, params: {'client_id': clientId, 'count': '$count', 'q': query});

  /// Сайт-авторизация — vkvideoapp через куки сайта
  static String oauthAuthorizeUrl({String? state}) {
    final s = state ?? DateTime.now().millisecondsSinceEpoch.toString();
    final params = {
      'client_id': oauthClientId,
      'scope': oauthScope,
      'redirect_uri': oauthRedirectUri,
      'display': 'mobile',
      'response_type': 'token',
      'v': vFallback,
      'revoke': '1',
      'state': s,
    };
    return '$hostOAuthAuthorize?${params.entries.map((e) => '${e.key}=${_urlEncode(e.value)}').join('&')}';
  }

  static String videoKey(int ownerId, int videoId, String? accessKey) =>
      accessKey == null || accessKey.isEmpty ? '${ownerId}_$videoId' : '${ownerId}_${videoId}_$accessKey';

  static String videoPageUrl(int ownerId, int videoId, String? accessKey) =>
      'https://vkvideo.ru/video${videoKey(ownerId, videoId, accessKey)}${accessKey == null || accessKey.isEmpty ? "" : "?access_key=$accessKey"}';

  // Аноним L0
  static String? _cachedAnon;
  static int _anonTs = 0;
  static Future<String> getAnonymToken({http.Client? client}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_cachedAnon != null && now - _anonTs < 3 * 3600 * 1000) return _cachedAnon!;
    final c = client ?? http.Client();
    const ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
    for (final cid in clientIds) {
      try {
        final resp = await c.post(Uri.parse(hostLogin), headers: {'User-Agent': ua, 'Origin': 'https://vkvideo.ru', 'Referer': 'https://vkvideo.ru/', 'Content-Type': 'application/x-www-form-urlencoded'}, body: 'client_id=$cid').timeout(const Duration(seconds: 8));
        if (resp.statusCode < 200 || resp.statusCode >= 300) continue;
        final j = jsonDecode(resp.body) as Map<String, dynamic>;
        final data = (j['data'] ?? j['response']) as Map<String, dynamic>?;
        final token = (data?['access_token'] ?? j['access_token'] ?? '').toString();
        if (token.isNotEmpty) {
          _cachedAnon = token;
          _anonTs = now;
          return token;
        }
      } catch (_) {}
    }
    throw Exception('VK anonym token failed');
  }
}
