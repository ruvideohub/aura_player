import 'dart:convert';
import 'package:http/http.dart' as http;
import 'vk_token_storage.dart';

class VkTrack {
  final int ownerId;
  final int id;
  final String title;
  final String artist;
  final String? url; // mp3/m3u8, может быть пустой пока не резолвнули
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

/// Минимальный порт KMP VkApiSource на Dart (audio.get, search, popular, auth)
class VkMusicApi {
  static const _oauth = 'https://oauth.vk.com/token';
  static const _api = 'https://api.vk.com/method';
  static const _v = '5.199';
  static const _clientId = '2274003';
  static const _clientSecret = 'hHbZxrka2uZ6jB1inYsH';
  static const _ua = 'VKAndroidApp/4.13.1-1206 (Android 4.4.3; SDK 19; armeabi; ; ru)';

  final http.Client _http;
  final VkTokenStorage _storage;
  VkMusicApi(this._http, this._storage);

  // ---- Auth (grant_type=password) с поддержкой captcha/2fa как в AuthFlow ----
  Future<void> auth(String login, String password, {String? captchaSid, String? captchaKey, String? code}) async {
    final uri = Uri.parse(_oauth).replace(queryParameters: {
      'grant_type': 'password',
      'client_id': _clientId,
      'client_secret': _clientSecret,
      'username': login,
      'password': password,
      'scope': 'audio,offline',
      '2fa_supported': '1',
      'v': _v,
      if (captchaSid != null) 'captcha_sid': captchaSid,
      if (captchaKey != null) 'captcha_key': captchaKey,
      if (code != null) 'code': code,
    });
    final r = await _http.get(uri, headers: {'User-Agent': _ua});
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if (j.containsKey('access_token')) {
      await _storage.save(j['access_token'] as String, (j['user_id'] as int));
      return;
    }
    // пробрасываем ошибку для UI (captcha_img, validation)
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

  Future<List<VkTrack>> search(String q, {int count = 50}) async {
    final token = _storage.token;
    if (token == null) throw Exception('Not authorized');
    final uri = Uri.parse('$_api/audio.search').replace(queryParameters: {
      'q': q, 'count': '$count', 'v': _v, 'access_token': token,
    });
    final r = await _http.get(uri, headers: {'User-Agent': _ua});
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final items = (j['response']?['items'] as List?) ?? [];
    return items.map((e) => VkTrack.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<VkTrack>> getPopular({int count = 50}) async {
    final token = _storage.token;
    if (token == null) throw Exception('Not authorized');
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
