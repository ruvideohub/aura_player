import 'dart:convert';
import 'package:http/http.dart' as http;
import 'vk_token_storage.dart';
import '../vk/vk_api.dart';

class VkTrack {
  final int ownerId;
  final int id;
  final String title;
  final String artist;
  final String? url;
  final int duration;
  final String? cover;
  VkTrack({required this.ownerId, required this.id, required this.title, required this.artist, this.url, required this.duration, this.cover});
  String get vkId => '${ownerId}_$id';
  factory VkTrack.fromJson(Map<String, dynamic> j) {
    return VkTrack(
      ownerId: (j['owner_id'] ?? 0) as int,
      id: (j['id'] ?? 0) as int,
      title: (j['title'] ?? '') as String,
      artist: (j['artist'] ?? '') as String,
      url: j['url'] as String?,
      duration: (j['duration'] ?? 0) as int,
      cover: (j['album']?['thumb']?['photo_300'] ?? j['album']?['thumb']?['photo_270']) as String?,
    );
  }
}

class VkMusicApi {
  static const _oauth = 'https://oauth.vk.ru/token';
  static const _oauthFallback = 'https://oauth.vk.com/token';
  static const _exchange = 'https://oauth.vk.ru/auth_by_exchange_token';
  static const _api = 'https://api.vk.ru/method';
  static const _v = '5.276';
  static const _clientId = '2274003';
  static const _clientSecret = 'hHbZxrka2uZ6jB1inYsH';
  static const _ua = 'VKAndroidApp/8.175-51775 (Android 12; SDK 31; arm64-v8a; ru; 1080x2400)';
  static const _sakVersion = '1.144.0';
  static const _flowType = 'tg_flow';

  static Map<String, String> get _headers => {
        'User-Agent': _ua,
        'X-VK-Android-Client': 'new',
        'Cache-Control': 'no-cache',
        'Accept': 'image/webp',
      };

  final http.Client _http;
  final VkTokenStorage _storage;
  VkMusicApi(this._http, this._storage);

  Future<void> auth(String login, String password, {String? captchaSid, String? captchaKey, String? code}) async {
    final body = {
      'grant_type': 'password',
      'client_id': _clientId,
      'client_secret': _clientSecret,
      'username': login,
      'password': password,
      'scope': 'all',
      '2fa_supported': '1',
      'v': _v,
      'sak_version': _sakVersion,
      'flow_type': _flowType,
      if (captchaSid != null) 'captcha_sid': captchaSid,
      if (captchaKey != null) 'captcha_key': captchaKey,
      if (code != null) 'code': code,
    };
    final r = await _http.post(Uri.parse(_oauth), headers: _headers, body: body);
    var j = _tryJson(r.body);
    // fallback на oauth.vk.com
    if ((j.containsKey('error') || r.statusCode != 200) && _oauthFallback != _oauth) {
      final r2 = await _http.post(Uri.parse(_oauthFallback), headers: _headers, body: body);
      j = _tryJson(r2.body);
      if (j.containsKey('access_token')) {
        await _storage.save(j['access_token'] as String, (j['user_id'] as int? ?? 0));
        if (j['exchange_token'] != null) await _storage.saveExchange(j['exchange_token'] as String);
        return;
      }
    }
    if (j.containsKey('access_token')) {
      await _storage.save(j['access_token'] as String, (j['user_id'] as int? ?? 0));
      if (j['exchange_token'] != null) await _storage.saveExchange(j['exchange_token'] as String);
      return;
    }
    throw VkAuthException(j);
  }

  // refresh токена при 1117 до 3 попыток
  Future<void> _refreshIfNeeded(int errorCode) async {
    if (errorCode != 1117) return;
    final ex = _storage.exchangeToken;
    if (ex == null || ex.isEmpty) return;
    for (int i = 0; i < 3; i++) {
      try {
        final r = await _http.post(Uri.parse(_exchange), headers: _headers, body: {'exchange_token': ex, 'client_id': _clientId, 'client_secret': _clientSecret, 'v': _v});
        final j = _tryJson(r.body);
        if (j.containsKey('access_token')) {
          await _storage.save(j['access_token'] as String, (j['user_id'] as int? ?? _storage.uid ?? 0));
          if (j['exchange_token'] != null) await _storage.saveExchange(j['exchange_token'] as String);
          return;
        }
      } catch (_) {}
    }
  }

  Future<List<VkTrack>> getMyAudio({int count = 500, int offset = 0}) async {
    final token = _storage.token;
    if (token == null) throw Exception('Not authorized — войди через Kate Mobile');
    final uid = _storage.uid;
    return _callAudio('audio.get', {'owner_id': '$uid', 'count': '$count', 'offset': '$offset'}, token);
  }

  Future<String> _effectiveToken() async {
    final t = _storage.token;
    if (t != null && t.isNotEmpty) return t;
    throw Exception('Войди в VK — audio требует авторизацию Kate Mobile (2274003)');
  }

  Future<List<VkTrack>> search(String q, {int count = 50}) async {
    final token = await _effectiveToken();
    return _callAudio('audio.search', {'q': q, 'count': '$count'}, token);
  }

  Future<List<VkTrack>> getPopular({int count = 50}) async {
    final token = await _effectiveToken();
    return _callAudio('audio.getPopular', {'count': '$count'}, token);
  }

  Future<List<VkTrack>> getById(List<String> audios) async {
    final token = await _effectiveToken();
    return _callAudio('audio.getById', {'audios': audios.join(',')}, token);
  }

  Future<Map<String, dynamic>> getLyrics(int lyricsId) async {
    final token = await _effectiveToken();
    return _callRaw('audio.getLyrics', {'lyrics_id': '$lyricsId'}, token);
  }

  Future<Map<String, dynamic>> _callRaw(String method, Map<String, String> extra, String token) async {
    final uri = Uri.parse('$_api/$method').replace(queryParameters: {...extra, 'v': _v, 'access_token': token});
    final r = await _http.get(uri, headers: _headers);
    final j = _tryJson(r.body);
    if (j['error'] != null) {
      final code = j['error']['error_code'] as int? ?? 0;
      if (code == 1117) {
        await _refreshIfNeeded(code);
        final retryToken = _storage.token;
        if (retryToken != null && retryToken != token) return _callRaw(method, extra, retryToken);
      }
      throw Exception('VK ${j['error']['error_code']}: ${j['error']['error_msg']}');
    }
    return j['response'] as Map<String, dynamic>? ?? j;
  }

  Future<List<VkTrack>> _callAudio(String method, Map<String, String> extra, String token) async {
    Future<Map<String, dynamic>> doGet(String host) async {
      final uri = Uri.parse('$host/method/$method').replace(queryParameters: {...extra, 'v': _v, 'access_token': token});
      final r = await _http.get(uri, headers: _headers);
      return _tryJson(r.body);
    }

    var j = await doGet('https://api.vk.ru');
    if (j['error'] != null) {
      final code = j['error']['error_code'] as int? ?? 0;
      if (code == 1117) {
        await _refreshIfNeeded(code);
        final nt = _storage.token;
        if (nt != null && nt != token) j = await doGet('https://api.vk.ru');
      }
    }
    if (j['error'] != null && (j['error']['error_code'] == 3 || j['error']['error_msg']?.toString().contains('Unknown method') == true)) {
      final j2 = await doGet('https://api.vk.com');
      if (j2['error'] == null) j = j2;
      else throw Exception('VK: ${j['error']['error_msg']} (code ${j['error']['error_code']}) — метод $method недоступен');
    }
    if (j['error'] != null) {
      final e = j['error'];
      // 1117 уже пробовали — бросаем
      throw Exception('VK ${e['error_code']}: ${e['error_msg']}');
    }
    final items = (j['response']?['items'] as List?) ?? (j['response'] as List?) ?? [];
    return items.map((e) => VkTrack.fromJson(e as Map<String, dynamic>)).toList();
  }

  Map<String, dynamic> _tryJson(String body) {
    try { return jsonDecode(body) as Map<String, dynamic>; } catch (_) { return {'error': {'error_msg': body}}; }
  }
}

class VkAuthException implements Exception {
  final Map<String, dynamic> payload;
  VkAuthException(this.payload);
  String get error => payload['error']?.toString() ?? 'unknown';
  String? get captchaImg => payload['captcha_img'] as String?;
  String? get captchaSid => payload['captcha_sid']?.toString();
  @override String toString() => 'VkAuthException: $payload';
}
