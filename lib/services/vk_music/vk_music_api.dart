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
  static const _oauth = 'https://oauth.vk.com/token';
  static const _api = 'https://api.vk.com/method';
  static const _v = '5.131';
  // VK site (6287487) — актуальный незабаненный ID, как просил пользователь
  static const _clientId = '6287487';
  static const _clientSecret = 'QbYic1K3lEV5kTGiqlq2';
  static const _ua = 'VKAndroidApp/8.12 (Android 11; SDK 30; arm64-v8a; ru; com.vkontakte.android)';

  final http.Client _http;
  final VkTokenStorage _storage;
  VkMusicApi(this._http, this._storage);

  // Старый прямой логин оставлен как fallback, но помечен deprecated — лучше через VkIdAuth или WebView
  Future<void> auth(String login, String password, {String? captchaSid, String? captchaKey, String? code}) async {
    final uri = Uri.parse(_oauth).replace(queryParameters: {
      'grant_type': 'password',
      'client_id': _clientId,
      'client_secret': _clientSecret,
      'username': login,
      'password': password,
      'scope': 'audio,offline,messages',
      '2fa_supported': '1',
      'v': _v,
      if (captchaSid != null) 'captcha_sid': captchaSid,
      if (captchaKey != null) 'captcha_key': captchaKey,
      if (code != null) 'code': code,
    });
    final r = await _http.get(uri, headers: {'User-Agent': _ua});
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if (j.containsKey('access_token')) {
      await _storage.save(j['access_token'] as String, (j['user_id'] as int? ?? 0));
      return;
    }
    throw VkAuthException(j);
  }

  Future<List<VkTrack>> getMyAudio({int count = 50, int offset = 0}) async {
    final token = _storage.token;
    if (token == null) throw Exception('Not authorized');
    final uid = _storage.uid;
    final uri = Uri.parse('$_api/audio.get').replace(queryParameters: {
      'owner_id': '$uid', 'count': '$count', 'offset': '$offset', 'v': _v, 'access_token': token,
    });
    final r = await _http.get(uri, headers: {'User-Agent': _ua});
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final items = (j['response']?['items'] as List?) ?? [];
    return items.map((e) => VkTrack.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<String> _effectiveToken() async {
    final t = _storage.token;
    if (t != null && t.isNotEmpty) return t;
    // L0: анонимный токен — поиск/популярное работают без логина
    return await VkApi.getAnonymToken(client: _http);
  }

  Future<List<VkTrack>> search(String q, {int count = 50}) async {
    final token = await _effectiveToken();
    final uri = Uri.parse('$_api/audio.search').replace(queryParameters: {
      'q': q, 'count': '$count', 'v': _v, 'access_token': token,
    });
    final r = await _http.get(uri, headers: {'User-Agent': _ua});
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final items = (j['response']?['items'] as List?) ?? [];
    return items.map((e) => VkTrack.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<VkTrack>> getPopular({int count = 50}) async {
    final token = await _effectiveToken();
    final uri = Uri.parse('$_api/audio.getPopular').replace(queryParameters: {
      'count': '$count', 'v': _v, 'access_token': token,
    });
    final r = await _http.get(uri, headers: {'User-Agent': _ua});
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final items = (j['response'] as List?) ?? [];
    return items.map((e) => VkTrack.fromJson(e as Map<String, dynamic>)).toList();
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
