import 'dart:convert';
import 'package:http/http.dart' as http;

/// Порт VkApiEndpoints.kt из vk.zip — единая точка истины по хостам/версиям/методам.
/// Никаких выдумок, только твоя логика.
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
  static const captchaNotRobot = '/method/captchaNotRobot';
  static const hostLiveApi = 'https://api.live.vkvideo.ru/v1';

  // ---------- Версии и клиенты ----------
  static const v = '5.199';
  static const vFallback = '5.131';
  static const vLegacy = '5.282';

  static const List<String> clientIds = [
    '52461373', // VK Video (web) — основной
    '51703666',
    '51858169', // клиент инфраструктуры vk.ru
    '2274003', // официальный Android-клиент VK
    '3140623',
    '6287487',
  ];

  static const oauthClientId = '51858169';
  static const oauthClientIdCom = '2274003';
  static const oauthScope = 'video,friends,groups,wall';

  // ---------- Методы ----------
  static const methodVideoSearch = 'video.search';
  static const methodCatalogVideoSearchWeb2 = 'catalog.getVideoSearchWeb2';
  static const methodGroupsSearch = 'groups.search';
  static const methodResolveScreenName = 'utils.resolveScreenName';
  static const methodExecute = 'execute';
  static const methodVideoGet = 'video.get';
  static const methodVideoGetAlbums = 'video.getAlbums';
  static const methodVideoGetAlbumById = 'video.getAlbumById';
  static const methodVideoGetAlbumsByVideo = 'video.getAlbumsByVideo';
  static const methodVideoGetComments = 'video.getComments';
  static const methodCatalogGetBlockItems = 'catalog.getBlockItems';
  static const methodCatalogGetOwnerVideosSearch = 'catalog.getOwnerVideosSearch';
  static const methodGroupsGetById = 'groups.getById';
  static const methodGroupsIsMember = 'groups.isMember';
  static const methodGroupsJoin = 'groups.join';
  static const methodGroupsLeave = 'groups.leave';
  static const methodUsersGet = 'users.get';
  static const methodUsersGetSubscriptions = 'users.getSubscriptions';
  static const methodWallGet = 'wall.get';
  static const methodWallGetComments = 'wall.getComments';
  static const methodFaveGet = 'fave.get';
  static const methodFaveAddVideo = 'fave.addVideo';
  static const methodFaveRemoveVideo = 'fave.removeVideo';
  static const methodFaveGetPages = 'fave.getPages';
  static const methodLikesAdd = 'likes.add';
  static const methodLikesDelete = 'likes.delete';
  static const methodLikesIsLiked = 'likes.isLiked';
  static const methodVideoCreateComment = 'video.createComment';
  static const methodVideoDeleteComment = 'video.deleteComment';
  static const methodVideoAdd = 'video.add';
  static const methodGetRelayAccessToken = 'get_relay_access_token';

  // ---------- Коды ошибок ----------
  static const errAuthFailed = 5;
  static const errRatePerSecond = 6;
  static const errFlood = 9;
  static const errAccessDenied = 15;
  static const errValidation = 17;
  static const errCaptcha = 14;
  static const errBadParams = 100;
  static const errVideoAccessDenied = 800;

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

  // --- video.* ---
  static String videoGet({
    required String token,
    int? ownerId,
    String? videos,
    int? albumId,
    int count = 20,
    int offset = 0,
    bool extended = true,
    String? fields,
  }) =>
      call(
        host: hostApi,
        name: methodVideoGet,
        token: token,
        params: {
          if (ownerId != null) 'owner_id': '$ownerId',
          if (videos != null) 'videos': videos,
          if (albumId != null) 'album_id': '$albumId',
          'count': '$count',
          'offset': '$offset',
          if (extended) 'extended': '1',
          if (fields != null) 'fields': fields,
        },
      );

  static String videoSearch({
    required String token,
    required String query,
    int count = 30,
    int offset = 0,
    int? sort,
    int? hd,
    int? longer,
    int? shorter,
  }) =>
      call(
        host: hostApi,
        name: methodVideoSearch,
        token: token,
        params: {
          'q': query,
          'count': '$count',
          'offset': '$offset',
          'extended': '1',
          if (sort != null) 'sort': '$sort',
          if (hd != null) 'hd': '$hd',
          if (longer != null) 'longer': '$longer',
          if (shorter != null) 'shorter': '$shorter',
        },
      );

  static String videoGetAlbums({required String token, required int ownerId, int count = 20, int offset = 0}) => call(
        host: hostApi,
        name: methodVideoGetAlbums,
        token: token,
        params: {'owner_id': '$ownerId', 'count': '$count', 'offset': '$offset', 'extended': '1'},
      );

  static String videoGetAlbumsByVideo({required String token, required String targetId, int? ownerId, int count = 20}) => call(
        host: hostApi,
        name: methodVideoGetAlbumsByVideo,
        token: token,
        params: {
          'target_id': targetId,
          'count': '$count',
          if (ownerId != null) 'owner_id': '$ownerId',
        },
      );

  static String videoGetComments({
    required String token,
    required int ownerId,
    required int videoId,
    int count = 30,
    int offset = 0,
    bool needLikes = true,
    bool extended = true,
  }) =>
      call(
        host: hostApi,
        name: methodVideoGetComments,
        token: token,
        params: {
          'owner_id': '$ownerId',
          'video_id': '$videoId',
          'count': '$count',
          'offset': '$offset',
          if (needLikes) 'need_likes': '1',
          if (extended) 'extended': '1',
        },
      );

  // --- catalog.* ---
  static String catalogVideoSearchWeb2({
    required String token,
    required String clientId,
    required String query,
    int count = 30,
    String? contentType,
    String? nextFrom,
  }) =>
      call(
        host: hostCatalog,
        name: methodCatalogVideoSearchWeb2,
        token: token,
        params: {
          'client_id': clientId,
          'count': '$count',
          'q': query,
          if (contentType != null) 'content_type': contentType,
          if (nextFrom != null) 'next_from': nextFrom,
        },
      );

  static String catalogGetBlockItems({
    required String token,
    required String clientId,
    String? blockIds,
    String? nextFrom,
    int count = 20,
  }) =>
      call(
        host: hostCatalog,
        name: methodCatalogGetBlockItems,
        token: token,
        params: {
          'client_id': clientId,
          'count': '$count',
          if (blockIds != null) 'block_ids': blockIds,
          if (nextFrom != null) 'next_from': nextFrom,
        },
      );

  static String groupsGetById({required String token, required String groupIds, String fields = 'description,members_count,cover,status,counters'}) =>
      call(host: hostApi, name: methodGroupsGetById, token: token, params: {'group_ids': groupIds, 'fields': fields});

  static String resolveScreenName({required String token, required String screenName}) =>
      call(host: hostApi, name: methodResolveScreenName, token: token, params: {'screen_name': screenName});

  // ---------- OAuth VK ID (L1): тела POST ----------
  static Map<String, String> oauthExchangeBody({
    required String code,
    required String codeVerifier,
    required String state,
    required String deviceId,
    String clientId = oauthClientId,
  }) =>
      {
        'grant_type': 'authorization_code',
        'code': code,
        'code_verifier': codeVerifier,
        'state': state,
        'device_id': deviceId,
        'redirect_uri': oauthRedirectUri,
        'client_id': clientId,
      };

  static Map<String, String> oauthRefreshBody({
    required String refreshToken,
    required String deviceId,
    required String state,
    String clientId = oauthClientId,
  }) =>
      {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': clientId,
        'device_id': deviceId,
        'state': state,
      };

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
      'lang_id': '$langId',
      'scheme': scheme,
      'scope': oauthScope,
      'prompt': prompt,
      'redirect_uri': oauthRedirectUri,
    };
    return '$hostOAuthAuthorize?${params.entries.map((e) => '${e.key}=${_urlEncode(e.value)}').join('&')}';
  }

  // ---------- Утилиты ----------
  static String videoKey(int ownerId, int videoId, String? accessKey) =>
      accessKey == null || accessKey.isEmpty ? '${ownerId}_$videoId' : '${ownerId}_${videoId}_$accessKey';

  static String videoPageUrl(int ownerId, int videoId, String? accessKey) =>
      'https://vkvideo.ru/video${videoKey(ownerId, videoId, accessKey)}${accessKey == null || accessKey.isEmpty ? '' : '?access_key=$accessKey'}';

  // Аноним L0 — как в твоем VkVideoLoader.getToken
  static String? _cachedAnon;
  static int _anonTs = 0;
  static Future<String> getAnonymToken({http.Client? client}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_cachedAnon != null && now - _anonTs < 60 * 60 * 1000) return _cachedAnon!;
    final c = client ?? http.Client();
    const ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/150.0.0.0 Safari/537.36';
    for (final cid in clientIds) {
      try {
        final resp = await c
            .post(
              Uri.parse(hostLogin),
              headers: {'User-Agent': ua, 'Origin': 'https://vkvideo.ru', 'Referer': 'https://vkvideo.ru/', 'Content-Type': 'application/x-www-form-urlencoded'},
              body: {'client_id': cid},
            )
            .timeout(const Duration(seconds: 8));
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
