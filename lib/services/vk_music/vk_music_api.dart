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
    if (token == null) throw Exception('Not authorized — войди через VK ID');
    final uid = _storage.uid;
    return _callAudio('audio.get', {'owner_id': '$uid', 'count': '$count', 'offset': '$offset'}, token);
  }

  Future<String> _effectiveToken() async {
    final t = _storage.token;
    if (t != null && t.isNotEmpty) return t;
    // Поиск без логина невозможен для audio.* (VK отдаёт 28 на анонимный токен)
    throw Exception('Войди в VK — поиск музыки требует авторизацию (VK закрыл audio для гостей)');
  }

  Future<List<VkTrack>> search(String q, {int count = 50}) async {
    final token = await _effectiveToken();
    return _callAudio('audio.search', {'q': q, 'count': '$count'}, token);
  }

  Future<List<VkTrack>> getPopular({int count = 50}) async {
    final token = await _effectiveToken();
    return _callAudio('audio.getPopular', {'count': '$count'}, token);
  }

  Future<List<VkTrack>> _callAudio(String method, Map<String, String> extra, String token) async {
    Future<Map<String, dynamic>> doGet(String host) async {
      final uri = Uri.parse('$host/method/$method').replace(queryParameters: {
        ...extra,
        'v': _v,
        'access_token': token,
      });
      final r = await _http.get(uri, headers: {'User-Agent': _ua});
      return jsonDecode(r.body) as Map<String, dynamic>;
    }

    var j = await doGet(_api);
    // fallback на api.vk.ru (у некоторых методов другой хост)
    if (j['error'] != null && (j['error']['error_code'] == 3 || j['error']['error_msg']?.toString().contains('Unknown method') == true)) {
      final j2 = await doGet('https://api.vk.ru');
      if (j2['error'] == null) j = j2;
      else {
        // VK сейчас режет audio.* для сторонних — отдаём понятный текст вместо "Unknown method passed"
        final msg = j['error']['error_msg'] ?? 'Unknown method passed';
        final code = j['error']['error_code'];
        throw Exception('VK: $msg (code $code) — VK закрыл метод $method для этого токена. '
            'Зайди через Kate Mobile токен или используй офлайн-библиотеку. '
            'Попробуй вставить токен от официального клиента: Профиль → Настройки → Вставить токен вручную');
      }
    }
    if (j['error'] != null) {
      final e = j['error'];
      throw Exception('VK ${e['error_code']}: ${e['error_msg']}');
    }
    final items = (j['response']?['items'] as List?) ?? (j['response'] as List?) ?? [];
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
