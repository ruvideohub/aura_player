import 'dart:convert';
import 'package:http/http.dart' as http;

/// Kate Mobile + api.vk.ru — как в таблице пользователя
/// client_id 2274003 / hHbZxrka2uZ6jB1inYsH, v=5.276, scope=all
class VkApi {
  // ---------- Хосты ----------
  static const hostApi = 'https://api.vk.ru';
  static const hostApiCom = 'https://api.vk.com';
  static const hostCatalog = 'https://api.vkvideo.ru';
  static const hostLogin = 'https://login.vk.com/?act=get_anonym_token';
  static const hostOAuthToken = 'https://oauth.vk.ru/token';
  static const hostOAuthTokenCom = 'https://oauth.vk.com/token';
  static const hostOAuthExchange = 'https://oauth.vk.ru/auth_by_exchange_token';
  static const hostOAuthAuthorize = 'https://id.vk.com/authorize';
  static const hostOAuthIdToken = 'https://id.vk.com/oauth2/auth';
  static const hostOAuthLogout = 'https://id.vk.com/oauth2/logout';
  static const oauthRedirectUri = 'https://oauth.vk.ru/blank.html';
  static const hostLiveApi = 'https://api.live.vkvideo.ru/v1';

  // ---------- Версии и клиенты (Kate Mobile) ----------
  static const v = '5.276';
  static const vFallback = '5.131';
  static const vLegacy = '5.282';

  // Kate Mobile — живой секрет
  static const kateClientId = '2274003';
  static const kateClientSecret = 'hHbZxrka2uZ6jB1inYsH';
  static const kateUserAgent = 'VKAndroidApp/8.175-51775 (Android 12; SDK 31; arm64-v8a; ru; 1080x2400)';
  static const sakVersion = '1.144.0';
  static const flowType = 'tg_flow';

  static const List<String> clientIds = [
    kateClientId, // Kate Mobile — primary
    '52461373',
    '51703666',
    '51858169',
    '3140623',
    '6287487',
  ];

  static const oauthClientId = kateClientId;
  static const oauthClientSecret = kateClientSecret;
  static const oauthScope = 'all';
  static const oauthScopeAudio = 'audio,offline';

  // Заголовки маскировки под официальное приложение
  static Map<String, String> get kateHeaders => {
        'User-Agent': kateUserAgent,
        'X-VK-Android-Client': 'new',
        'Cache-Control': 'no-cache',
        'Accept': 'image/webp',
      };

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
  // Аудио (Kate)
  static const methodAudioGet = 'audio.get';
  static const methodAudioSearch = 'audio.search';
  static const methodAudioGetById = 'audio.getById';
  static const methodAudioGetCount = 'audio.getCount';
  static const methodAudioGetLyrics = 'audio.getLyrics';
  static const methodAudioGetPopular = 'audio.getPopular';
  static const methodCatalogGetAudio = 'catalog.getAudio';
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
  static const errTokenExpired = 1117;

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
  static String videoGet({required String token, int? ownerId, String? videos, int? albumId, int count = 20, int offset = 0, bool extended = true, String? fields}) => call(host: hostApi, name: methodVideoGet, token: token, params: {if (ownerId != null) 'owner_id': '$ownerId', if (videos != null) 'videos': videos, if (albumId != null) 'album_id': '$albumId', 'count': '$count', 'offset': '$offset', if (extended) 'extended': '1', if (fields != null) 'fields': fields});
  static String videoSearch({required String token, required String query, int count = 30, int offset = 0, int? sort, int? hd, int? longer, int? shorter}) => call(host: hostApi, name: methodVideoSearch, token: token, params: {'q': query, 'count': '$count', 'offset': '$offset', 'extended': '1', if (sort != null) 'sort': '$sort', if (hd != null) 'hd': '$hd', if (longer != null) 'longer': '$longer', if (shorter != null) 'shorter': '$shorter'});
  static String videoGetAlbums({required String token, required int ownerId, int count = 20, int offset = 0}) => call(host: hostApi, name: methodVideoGetAlbums, token: token, params: {'owner_id': '$ownerId', 'count': '$count', 'offset': '$offset', 'extended': '1'});
  static String videoGetAlbumsByVideo({required String token, required String targetId, int? ownerId, int count = 20}) => call(host: hostApi, name: methodVideoGetAlbumsByVideo, token: token, params: {'target_id': targetId, 'count': '$count', if (ownerId != null) 'owner_id': '$ownerId'});
  static String videoGetComments({required String token, required int ownerId, required int videoId, int count = 30, int offset = 0, bool needLikes = true, bool extended = true}) => call(host: hostApi, name: methodVideoGetComments, token: token, params: {'owner_id': '$ownerId', 'video_id': '$videoId', 'count': '$count', 'offset': '$offset', if (needLikes) 'need_likes': '1', if (extended) 'extended': '1'});

  // --- audio.* Kate ---
  static String audioGet({required String token, required int ownerId, int count = 500, int offset = 0}) => call(host: hostApi, name: methodAudioGet, token: token, params: {'owner_id': '$ownerId', 'count': '$count', 'offset': '$offset'});
  static String audioSearch({required String token, required String query, int count = 50, int offset = 0}) => call(host: hostApi, name: methodAudioSearch, token: token, params: {'q': query, 'count': '$count', 'offset': '$offset'});
  static String audioGetById({required String token, required String audios}) => call(host: hostApi, name: methodAudioGetById, token: token, params: {'audios': audios});
  static String audioGetCount({required String token, required int ownerId}) => call(host: hostApi, name: methodAudioGetCount, token: token, params: {'owner_id': '$ownerId'});
  static String audioGetLyrics({required String token, required int lyricsId}) => call(host: hostApi, name: methodAudioGetLyrics, token: token, params: {'lyrics_id': '$lyricsId'});

  // --- catalog.* ---
  static String catalogVideoSearchWeb2({required String token, required String clientId, required String query, int count = 30, String? contentType, String? nextFrom}) => call(host: hostCatalog, name: methodCatalogVideoSearchWeb2, token: token, params: {'client_id': clientId, 'count': '$count', 'q': query, if (contentType != null) 'content_type': contentType, if (nextFrom != null) 'next_from': nextFrom});
  static String catalogGetBlockItems({required String token, required String clientId, String? blockIds, String? nextFrom, int count = 20}) => call(host: hostCatalog, name: methodCatalogGetBlockItems, token: token, params: {'client_id': clientId, 'count': '$count', if (blockIds != null) 'block_ids': blockIds, if (nextFrom != null) 'next_from': nextFrom});
  static String groupsGetById({required String token, required String groupIds, String fields = 'description,members_count,cover,status,counters'}) => call(host: hostApi, name: methodGroupsGetById, token: token, params: {'group_ids': groupIds, 'fields': fields});
  static String resolveScreenName({required String token, required String screenName}) => call(host: hostApi, name: methodResolveScreenName, token: token, params: {'screen_name': screenName});

  // ---------- OAuth Kate ----------
  static Map<String, String> kateAuthBody({required String username, required String password, String? captchaSid, String? captchaKey, String? code}) => {
        'grant_type': 'password',
        'client_id': kateClientId,
        'client_secret': kateClientSecret,
        'username': username,
        'password': password,
        'scope': oauthScope,
        'v': v,
        '2fa_supported': '1',
        'sak_version': sakVersion,
        'flow_type': flowType,
        if (captchaSid != null) 'captcha_sid': captchaSid,
        if (captchaKey != null) 'captcha_key': captchaKey,
        if (code != null) 'code': code,
      };

  static Map<String, String> exchangeTokenBody({required String accessToken}) => {
        'access_token': accessToken,
        'client_id': kateClientId,
        'client_secret': kateClientSecret,
        'v': v,
      };

  // ---------- OAuth VK ID (PKCE) — оставляем для WebView ----------
  static Map<String, String> oauthExchangeBody({required String code, required String codeVerifier, required String state, required String deviceId, String clientId = kateClientId}) => {'grant_type': 'authorization_code', 'code': code, 'code_verifier': codeVerifier, 'state': state, 'device_id': deviceId, 'redirect_uri': oauthRedirectUri, 'client_id': clientId};
  static Map<String, String> oauthRefreshBody({required String refreshToken, required String deviceId, required String state, String clientId = kateClientId}) => {'grant_type': 'refresh_token', 'refresh_token': refreshToken, 'client_id': clientId, 'device_id': deviceId, 'state': state};
  static String oauthAuthorizeUrl({required String codeChallenge, required String state, int langId = 0, String scheme = 'space_gray', String prompt = 'login', String clientId = kateClientId}) {
    final params = {'state': state, 'response_type': 'code', 'code_challenge': codeChallenge, 'code_challenge_method': 'S256', 'client_id': clientId, 'lang_id': '$langId', 'scheme': scheme, 'scope': 'video,friends,groups,wall', 'prompt': prompt, 'redirect_uri': oauthRedirectUri};
    return '$hostOAuthAuthorize?${params.entries.map((e) => '${e.key}=${_urlEncode(e.value)}').join('&')}';
  }

  static String videoKey(int ownerId, int videoId, String? accessKey) => accessKey == null || accessKey.isEmpty ? '${ownerId}_$videoId' : '${ownerId}_${videoId}_$accessKey';
  static String videoPageUrl(int ownerId, int videoId, String? accessKey) => 'https://vkvideo.ru/video${videoKey(ownerId, videoId, accessKey)}${accessKey == null || accessKey.isEmpty ? '' : '?access_key=$accessKey'}';

  // Аноним L0
  static String? _cachedAnon;
  static int _anonTs = 0;
  static Future<String> getAnonymToken({http.Client? client}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_cachedAnon != null && now - _anonTs < 60 * 60 * 1000) return _cachedAnon!;
    final c = client ?? http.Client();
    for (final cid in clientIds) {
      try {
        final resp = await c.post(Uri.parse(hostLogin), headers: {...kateHeaders, 'Origin': 'https://vkvideo.ru', 'Referer': 'https://vkvideo.ru/', 'Content-Type': 'application/x-www-form-urlencoded'}, body: {'client_id': cid}).timeout(const Duration(seconds: 8));
        if (resp.statusCode < 200 || resp.statusCode >= 300) continue;
        final j = jsonDecode(resp.body) as Map<String, dynamic>;
        final data = (j['data'] ?? j['response']) as Map<String, dynamic>?;
        final token = (data?['access_token'] ?? j['access_token'] ?? '').toString();
        if (token.isNotEmpty) {_cachedAnon = token; _anonTs = now; return token;}
      } catch (_) {}
    }
    throw Exception('VK anonym token failed');
  }
}
