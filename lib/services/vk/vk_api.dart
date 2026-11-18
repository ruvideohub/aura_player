import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Порт VkApi.kt — единая карта эндпоинтов.
/// Никаких Android-зависимостей, только dart:convert / stdlib.
class VkApi {
  // ---------- Хосты ----------
  static const hostApi = 'https://api.vk.com';
  static const hostApiRu = 'https://api.vk.ru';
  static const hostCatalog = 'https://api.vkvideo.ru';
  static const hostLogin = 'https://login.vk.com/?act=get_anonym_token';
  static const hostOAuthAuthorize = 'https://id.vk.com/authorize';
  static const hostOAuthToken = 'https://id.vk.com/oauth2/auth';
  static const hostOAuthLogout = 'https://id.vk.com/oauth2/logout';
  static const oauthRedirectUri = 'https://oauth.vk.ru/blank.html';
  static const hostLiveApi = 'https://api.live.vkvideo.ru/v1';

  // ---------- Версии ----------
  static const v = '5.199';
  static const vFallback = '5.131';
  static const vLegacy = '5.282';

  static const List<String> clientIds = [
    '52461373', // VK Video (web) — основной
    '51703666',
    '51858169',
    '2274003',
    '3140623',
    '6287487',
  ];

  // Сайт ВК — единственный незабаненный для авторизации (по просьбе пользователя)
  static const oauthClientId = '6287487'; // vk.com site, secret QbYic1K3lEV5kTGiqlq2
  static const oauthClientIdCom = '2274003';
  static const oauthScope = 'video,friends,groups,wall';

  // ---------- Методы ----------
  static const _videoSearch = 'video.search';
  static const _catalogVideoSearchWeb2 = 'catalog.getVideoSearchWeb2';
  static const _videoGet = 'video.get';
  static const _groupsGetById = 'groups.getById';
  static const _resolveScreenName = 'utils.resolveScreenName';
  static const _faveGet = 'fave.get';
  static const _likesAdd = 'likes.add';
  static const _getRelay = 'get_relay_access_token';

  // Коды ошибок
  static const errAuthFailed = 5;
  static const errRate = 6;
  static const errFlood = 9;
  static const errAccessDenied = 15;
  static const errValidation = 17;
  static const errCaptcha = 14;

  static String _urlEncode(String s) => Uri.encodeComponent(s);

  static String call({
    required String host,
    required String name,
    String? token,
    String version = v,
    Map<String, String> params = const {},
  }) {
    final sb = StringBuffer('$host/method/$name?v=$version');
    if (token != null && token.isNotEmpty) {
      sb.write('&access_token=${_urlEncode(token)}');
    }
    for (final e in params.entries) {
      sb.write('&${e.key}=${_urlEncode(e.value)}');
    }
    return sb.toString();
  }

  static String videoSearch({
    required String token,
    required String query,
    int count = 30,
    int offset = 0,
    int? sort,
    int? hd,
    int? longer,
    int? shorter,
  }) {
    return call(
      host: hostApi,
      name: _videoSearch,
      token: token,
      params: {
        'q': query,
        'count': count.toString(),
        'offset': offset.toString(),
        'extended': '1',
        if (sort != null) 'sort': sort.toString(),
        if (hd != null) 'hd': hd.toString(),
        if (longer != null) 'longer': longer.toString(),
        if (shorter != null) 'shorter': shorter.toString(),
      },
    );
  }

  static String videoGet({
    required String token,
    int? ownerId,
    String? videos,
    int? albumId,
    int count = 20,
    int offset = 0,
    bool extended = true,
    String? fields,
  }) {
    return call(
      host: hostApi,
      name: _videoGet,
      token: token,
      params: {
        if (ownerId != null) 'owner_id': ownerId.toString(),
        if (videos != null) 'videos': videos,
        if (albumId != null) 'album_id': albumId.toString(),
        'count': count.toString(),
        'offset': offset.toString(),
        if (extended) 'extended': '1',
        if (fields != null) 'fields': fields,
      },
    );
  }

  static String catalogVideoSearchWeb2({
    required String token,
    required String clientId,
    required String query,
    int count = 30,
    String? contentType,
    String? nextFrom,
  }) {
    return call(
      host: hostCatalog,
      name: _catalogVideoSearchWeb2,
      token: token,
      params: {
        'client_id': clientId,
        'count': count.toString(),
        'q': query,
        if (contentType != null) 'content_type': contentType,
        if (nextFrom != null) 'next_from': nextFrom,
      },
    );
  }

  // ---------- OAuth VK ID (L1) ----------
  static Map<String, String> oauthExchangeBody({
    required String code,
    required String codeVerifier,
    required String state,
    required String deviceId,
    String clientId = oauthClientId,
  }) {
    return {
      'grant_type': 'authorization_code',
      'code': code,
      'code_verifier': codeVerifier,
      'state': state,
      'device_id': deviceId,
      'redirect_uri': oauthRedirectUri,
      'client_id': clientId,
    };
  }

  static Map<String, String> oauthRefreshBody({
    required String refreshToken,
    required String deviceId,
    required String state,
    String clientId = oauthClientId,
  }) {
    return {
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'client_id': clientId,
      'device_id': deviceId,
      'state': state,
    };
  }

  static String oauthAuthorizeUrl({
    required String codeChallenge,
    required String state,
    int langId = 0,
    String scheme = 'space_gray',
    String prompt = 'login',
    String clientId = oauthClientId,
  }) {
    final params = {
      'state': state,
      'response_type': 'code',
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'client_id': clientId,
      'lang_id': langId.toString(),
      'scheme': scheme,
      'scope': oauthScope,
      'prompt': prompt,
      'redirect_uri': oauthRedirectUri,
    };
    final qs = params.entries.map((e) => '${e.key}=${_urlEncode(e.value)}').join('&');
    return '$hostOAuthAuthorize?$qs';
  }

  static String videoKey(int ownerId, int videoId, String? accessKey) {
    if (accessKey == null || accessKey.isEmpty) return '${ownerId}_$videoId';
    return '${ownerId}_${videoId}_$accessKey';
  }

  static String videoPageUrl(int ownerId, int videoId, String? accessKey) {
    return 'https://vkvideo.ru/video${videoKey(ownerId, videoId, accessKey)}'
        '${accessKey == null || accessKey.isEmpty ? "" : "?access_key=$accessKey"}';
  }

  // ---------- Анонимный токен L0 (без логина) ----------
  static String? _cachedAnon;
  static int _anonTs = 0;

  static Future<String> getAnonymToken({http.Client? client}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_cachedAnon != null && now - _anonTs < 3 * 3600 * 1000) return _cachedAnon!;
    final c = client ?? http.Client();
    const ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
    for (final cid in clientIds) {
      try {
        final resp = await c.post(
          Uri.parse(hostLogin),
          headers: {
            'User-Agent': ua,
            'Origin': 'https://vkvideo.ru',
            'Referer': 'https://vkvideo.ru/',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: 'client_id=$cid',
        ).timeout(const Duration(seconds: 8));
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
