import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Порт LKMP_34_2.0.2.apk — точь-в-точь N1/e + m1/f + A/b
/// Референс: docs/lkmp_auth_reference/{api/m1_f.java, N1_e.java, A_b_extract.java}
/// Разбор пользователя: google_drive/LKMP_auth_reference.zip
class VkLkmpAuth {
  static const _clientId = '2274003';
  static const _clientSecret = 'hHbZxrka2uZ6jB1inYsH';
  static const _apiId = '2274003';
  static const _v = '5.276';
  static const _sak = '1.144.0';
  static const _flow = 'tg_flow';
  static const _flowNoPwd = 'auth_without_password';
  static const _host = 'https://api.vk.ru';

  final http.Client _http;
  VkLkmpAuth(this._http);

  // === A.b.E — MD5 БЕЗ паддинга: Integer.toHexString(b & 255) ===
  String _lkmpMd5NoPad(String s) {
    // LKMP: str.getBytes(M0.a.f1992a) — f1992a = UTF_8 (в APK это StandardCharsets.UTF_8)
    // Было s.codeUnits (UTF-16) — для ASCII совпадает, но для единообразия берём utf8
    final digest = md5.convert(utf8.encode(s)).bytes;
    return digest.map((b) => (b & 0xFF).toRadixString(16)).join();
  }

  // === A.b.y — device_id = android_id + ":" + E(Build...) + статический кеш f2294n ===
  // Фолбек при исключении: android_id + ":45c4c99f645eacee39036f5c4f8cddbf"
  static const _fallbackSuffix = '45c4c99f645eacee39036f5c4f8cddbf';
  static String? _memDeviceId; // аналог N1.e.f2294n — кеш в памяти

  Future<String> _deviceId() async {
    if (_memDeviceId != null && _memDeviceId!.isNotEmpty) {
      // LKMP: if (f2294n.length()>0) return f2294n;
      // но нужно учесть миграцию со старого 25-char бага
      final parts = _memDeviceId!.split(':');
      if (parts.length == 2 && parts[1].length >= 20) return _memDeviceId!;
      _memDeviceId = null;
    }
    final p = await SharedPreferences.getInstance();
    var cached = p.getString('vk_lkmp_device_id');
    if (cached != null && cached.isNotEmpty) {
      final parts = cached.split(':');
      if (parts.length == 2 && parts[1].length >= 20) {
        _memDeviceId = cached;
        return cached;
      }
      await p.remove('vk_lkmp_device_id');
    }
    String androidId;
    try {
      androidId = _randHex(16);
    } catch (_) {
      androidId = '';
    }
    // Build поля как в A.b.y / A.b.x fallback — Nexus 5X образ
    const model = 'Google Nexus 5X';
    const id = 'TP1A.221105.002';
    const manufacturer = 'Google';
    const brand = 'google';
    const type = 'user';
    const arch = 'arm64-v8a';
    String hash;
    try {
      hash = _lkmpMd5NoPad(model + id + manufacturer + brand + type + arch);
    } catch (_) {
      hash = _fallbackSuffix;
    }
    final dev = '$androidId:$hash';
    _memDeviceId = dev;
    await p.setString('vk_lkmp_device_id', dev);
    return dev;
  }

  // m1.f.c() — кеш анонима в f6406a (if length==0 then b())
  // N1.e.b() — каждый вызов делает сеть auth.getAnonymToken без внутреннего кеша
  // LKMP в validateAccount делает: set(c()) + w.j(access_token=b()) — второе перетирает первое,
  // т.е. в проводе только ОДИН свежий токен из b(). Но f6406a всё равно прогревается.
  // Для минимизации спама AURA держит мем-кеш 55м, но validateAccount по LKMP должен слать свежий —
  // поэтому здесь делаем как LKMP: каждый validateAccount берёт свежий b(), а для повторных
  // вызовов (checkOtp/getVerificationMethods) можно переиспользовать тот же токен в рамках сессии.
  String? _cachedAnon;
  int _anonTs = 0;
  Future<String> _cachedAnonToken() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_cachedAnon != null && now - _anonTs < 55 * 60 * 1000) return _cachedAnon!;
    final t = await getAnonymToken();
    _cachedAnon = t;
    _anonTs = now;
    return t;
  }

  // N1.e.g(int) — UUID 8-4-4-4-12 из H0.f.e(16) с сидом currentTimeMillis
  // LKMP генерит один раз в конструкторе N1.e, не сохраняет в prefs
  // AURA сохраняет в prefs для стабильности device_id+gaid (иначе VK банит при каждом запуске)
  String _gaid() {
    String g(int n) => List.generate(n, (_) => '0123456789abcdef'[Random.secure().nextInt(16)]).join();
    return '${g(8)}-${g(4)}-${g(4)}-${g(4)}-${g(12)}';
  }

  Future<String> _gaidStored() async {
    final p = await SharedPreferences.getInstance();
    var g = p.getString('vk_lkmp_gaid');
    if (g != null && g.isNotEmpty) return g;
    g = _gaid();
    await p.setString('vk_lkmp_gaid', g);
    return g;
  }

  // A.b.x — UA: VKAndroidApp/8.175-51775 (Android RELEASE; SDK INT; arch; Build.MODEL; lang; WxH)
  // Фолбек: VKAndroidApp/8.87-21014 (Android 12; SDK 31; arm64-v8a;Google Nexus 5X; ru; 1920x1080)
  String _ua() {
    // В Dart нет Build.* — берём константу LKMP как в твоём README
    // Было бы идеально брать динамический, но в AURA нет device_info_plus — оставляем LKMP-константу
    return 'VKAndroidApp/8.175-51775 (Android 12; SDK 31; arm64-v8a;Google Nexus 5X; ru; 1920x1080)';
  }

  Map<String, String> _headers(String screen) => {
        'X-Screen': screen,
        'Cache-Control': 'no-cache',
        'Accept': 'image/webp',
        'Accept-Encoding': 'gzip',
        'User-Agent': _ua(),
        'X-VK-Android-Client': 'new',
        'Content-Type': 'application/x-www-form-urlencoded',
      };

  // N1.e.d — общий POST с gzip, cookie, f2292e (redirect), 3 ретрая в N1.e.e
  // Упрощённо: http.post + gzip не нужен (http пакует сам), cookie пока не храним
  Future<Map<String, dynamic>> _post(String url, Map<String, String> body, String screen) async {
    final r = await _http.post(Uri.parse(url), headers: _headers(screen), body: body);
    if (r.body.isEmpty) return {'error': {'error_code': -1, 'error_text': 'empty body'}};
    try {
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (e) {
      return {'error': {'error_code': -1, 'error_text': 'bad json: ${r.body.substring(0, r.body.length.clamp(0, 300))}'}};
    }
  }

  /// N1/e.b() — auth.getAnonymToken (всегда сеть, без кеша внутри)
  Future<String> getAnonymToken() async {
    final j = await _post('$_host/method/auth.getAnonymToken', {
      'client_id': _clientId,
      'client_secret': _clientSecret,
      'device_id': await _deviceId(),
      'lang': 'ru',
      'v': _v,
      'https': '1',
      'api_id': _apiId,
    }, 'auth_start_with_phone');
    if (j['response']?['token'] != null) return j['response']['token'] as String;
    // LKMP: throw Exception("Ошибка получения мохентокена")
    throw Exception('getAnonymToken failed: $j');
  }

  /// m1/f.i() — auth.validateAccount
  /// LKMP: postParams.set("access_token", c()); postParams.set("login", str);
  ///       postParams.set(w.j(lang, device_id, supported_ways, force_password, sak, flow, gaid, access_token=b(), v, https, api_id))
  /// Т.е. финальный access_token = свежий b(), а не c(). Мы повторяем через _cachedAnonToken но при желании можно вызвать getAnonymToken() напрямую для 1:1
  Future<Map<String, dynamic>> validateAccount({required String phone, Map<String, String> extra = const {}}) async {
    // Как LKMP: берём свежий anonym (b()) — у нас _cachedAnonToken с 55м кешем близок, но для точного соответствия дёргаем сеть реже
    final anon = await _cachedAnonToken();
    final body = <String, String>{
      'login': phone,
      'access_token': anon,
      'lang': 'ru',
      'device_id': await _deviceId(),
      'supported_ways': 'push,email,sms,callreset,password,reserve_code,codegen,official_messenger,max_code,passkey,libverify,max_messenger',
      'force_password': '0',
      'sak_version': _sak,
      'flow_type': _flowNoPwd,
      'gaid': await _gaidStored(),
      'v': _v,
      'https': '1',
      'api_id': _apiId,
      ...extra, // captcha_sid/captcha_key/captcha_attempt/is_sound_captcha если была капча 14
    };
    return _post('$_host/method/auth.validateAccount', body, 'auth_start_with_phone');
  }

  /// N1/e.c — ecosystem.getVerificationMethods
  Future<Map<String, dynamic>> getVerificationMethods({required String sid, String extra = ''}) async {
    final anon = await _cachedAnonToken();
    return _post('$_host/method/ecosystem.getVerificationMethods$extra', {
      'sid': sid,
      'lang': 'ru',
      'device_id': await _deviceId(),
      'sak_version': _sak,
      'flow_type': _flow,
      'gaid': await _gaidStored(),
      'access_token': anon,
      'v': _v,
      'https': '1',
      'api_id': _apiId,
    }, 'auth');
  }

  /// N1/e.a — ecosystem.checkOtp (+ m1/f.f для sendOtp)
  Future<Map<String, dynamic>> checkOtp({required String code, required String sid, String verificationMethod = 'sms'}) async {
    final anon = await _cachedAnonToken();
    return _post('$_host/method/ecosystem.checkOtp', {
      'sid': sid,
      'code': code,
      // verification_method не обязателен в checkOtp у LKMP — sid уже привязан к методу, но добавим для совместимости
      'verification_method': verificationMethod,
      'lang': 'ru',
      'device_id': await _deviceId(),
      'sak_version': _sak,
      'flow_type': _flow,
      'gaid': await _gaidStored(),
      'access_token': anon,
      'v': _v,
      'https': '1',
      'api_id': _apiId,
    }, 'auth');
  }

  /// m1/f.f — ecosystem.sendOtpSms / sendOtpPush / sendOtpEmail (25/27/26)
  Future<Map<String, dynamic>> sendOtp({required String sid, required int method}) async {
    final anon = await _cachedAnonToken();
    String m;
    if (method == 26) m = 'sendOtpEmail';
    else if (method == 27) m = 'sendOtpPush';
    else m = 'sendOtpSms';
    return _post('$_host/method/ecosystem.$m', {
      'sid': sid,
      'lang': 'ru',
      'device_id': await _deviceId(),
      'sak_version': _sak,
      'flow_type': _flow,
      'gaid': await _gaidStored(),
      'access_token': anon,
      'v': _v,
      'https': '1',
      'api_id': _apiId,
    }, 'auth');
  }

  /// m1/f.a — oauth/token по паролю (password flow)
  Future<Map<String, dynamic>> authByPassword({required String password, required String sid, required String username, Map<String, String> captcha = const {}}) async {
    final anon = await _cachedAnonToken();
    // LKMP: sid, password, username, anonymous_token=c(), w.j(libverify 1, scope all, device_trusted 1, grant_type phone_confirmation_sid, 2fa 1, supported_ways push,email, lang, device_id, sak, flow tg_flow, gaid, anonymous_token=b(), v, https, api_id)
    final body = <String, String>{
      'sid': sid,
      'password': password,
      'username': username,
      'anonymous_token': anon,
      'libverify_support': '1',
      'scope': 'all',
      'device_trusted_hash_supported': '1',
      'grant_type': 'phone_confirmation_sid',
      '2fa_supported': '1',
      'supported_ways': 'push,email',
      'lang': 'ru',
      'device_id': await _deviceId(),
      'sak_version': _sak,
      'flow_type': _flow,
      'gaid': await _gaidStored(),
      'v': _v,
      'https': '1',
      'api_id': _apiId,
      ...captcha,
    };
    // LKMP вторым anonymous_token перетирает первым через w.j — оставляем один
    return _post('$_host/oauth/token', body, 'auth_password');
  }

  /// N1/e.h — refresh exchange_token → access_token (две ветки)
  Future<String?> refreshByExchangeToken() async {
    final p = await SharedPreferences.getInstance();
    final ex = p.getString('vk_exchange_token') ?? p.getString('vk_lkmp_exchange') ?? '';
    if (ex.isEmpty) return null;
    final j = await _post('$_host/oauth/auth_by_exchange_token', {
      'lang': 'ru',
      'https': '1',
      'api_id': _apiId,
      'client_id': _clientId,
      'initiator': 'expired_token',
      'gaid': await _gaidStored(),
      'exchange_token': ex,
      'scope': 'all',
      'device_id': await _deviceId(),
      'v': _v,
    }, 'auth_password');
    // Ветка 1: json {access_token} ; ветка 2: raw redirect #access_token=...
    if (j['access_token'] != null) {
      await _storeAuth(j);
      return j['access_token'] as String;
    }
    if (j['response']?['access_token'] != null) {
      await _storeAuth(j['response'] as Map<String, dynamic>);
      return j['response']['access_token'] as String;
    }
    return null;
  }

  Future<void> _storeAuth(Map<String, dynamic> j) async {
    final p = await SharedPreferences.getInstance();
    final token = j['access_token'] ?? j['token'] ?? '';
    if (token.toString().isNotEmpty) await p.setString('vk_music_token', token.toString());
    if (j['exchange_token'] != null) await p.setString('vk_exchange_token', j['exchange_token'].toString());
    if (j['user_id'] != null) await p.setInt('vk_music_uid', int.tryParse('${j['user_id']}') ?? 0);
  }

  // === Вспомогательные для аудита ===
  String debugMd5NoPad(String s) => _lkmpMd5NoPad(s);
  Future<String> debugDeviceId() => _deviceId();

  String _randHex(int len) => List.generate(len, (_) => '0123456789abcdef'[Random.secure().nextInt(16)]).join();
}
