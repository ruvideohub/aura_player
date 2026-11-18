import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Порт LKMP_34_2.0.2.apk — 1:1 по api/N1_e.java (HTTP-ядро) и api/m1_f.java (логика).
///
/// Флоу: auth.getAnonymToken → auth.validateAccount → ecosystem.sendOtp{Sms,Push,Email}
/// → ecosystem.checkOtp → oauth/token (grant_type=phone_confirmation_sid)
/// → пост-логин (execute.getUserInfo func_v=33 needExchangeToken=1 → exchange_token,
/// auth.refreshToken, account.getProfileInfo).
///
/// Что исправлено относительно прежней версии (см. README_FIX.md):
///  1. oauth/token теперь на https://api.vk.ru/oauth/token с grant_type=phone_confirmation_sid,
///     sid, anonymous_token, libverify_support и т.д. (как m1_f.a), а не grant_type=password.
///  2. checkOtp передаёт verification_method (g1_RunnableC0313D.java:124).
///  3. Добавлен ecosystem.sendOtp* (m1_f.f) — без него SMS/push/email не отправляются.
///  4. getVerificationMethods парсит response.methods[] (B_RunnableC0023l0.java:127),
///     а не несуществующее response.verification_methods.
///  5. Cookie-хранилище как CookieManager(ACCEPT_ALL) в N1_e.java:96-98.
///  6. Пост-логин с получением exchange_token (m1_f.b) — без него refresh невозможен.
///  7. refreshByExchangeToken парсит fragment-ответ "#access_token=..." (N1_e.h:346-356).
///     иначе тело ответа могло приходить нераспакованным и jsonDecode падал.
///  9. Обработка капчи (error_code 14 и need_captcha) и flood (error 9) через типизированное
///     исключение — UI показывает капчу вместо «блокировки».
/// 10. Retry: 3 сетевые попытки (N1.e.e) и до 3 повторов при 1117 с обменом exchange-токена
///     (N1_b.java case 0).

// ---------------------------------------------------------------------------
// Типы результатов и ошибок
// ---------------------------------------------------------------------------

/// Капча (порт m1.h): приходит и как error_code=14 (поля внутри error),
/// и как error=need_captcha в oauth/token (поля в корне ответа).
class VkLkmpCaptcha {
  final String img;
  final String ratio;
  final String sid;
  final String ts;
  final String redirectUri;

  const VkLkmpCaptcha({
    required this.img,
    required this.ratio,
    required this.sid,
    required this.ts,
    required this.redirectUri,
  });

  factory VkLkmpCaptcha.fromMap(Map<String, dynamic> m) => VkLkmpCaptcha(
        img: '${m['captcha_img'] ?? ''}',
        ratio: '${m['captcha_ratio'] ?? ''}',
        sid: '${m['captcha_sid'] ?? ''}',
        ts: '${m['captcha_ts'] ?? ''}',
        redirectUri: '${m['redirect_uri'] ?? ''}',
      );

  bool get isEmpty => img.isEmpty && sid.isEmpty;
}

/// Типизированная ошибка авторизации.
/// kind: flood | captcha | invalid_client | need_validation | api | network
class VkLkmpAuthException implements Exception {
  final String kind;
  final String message;
  final Map<String, dynamic> raw;
  final VkLkmpCaptcha? captcha;
  final String validationType;

  const VkLkmpAuthException({
    required this.kind,
    required this.message,
    this.raw = const {},
    this.captcha,
    this.validationType = '',
  });

  @override
  String toString() => '[$kind] $message';
}

/// Результат входа по паролю (m1.f.a): либо успех (после пост-логина),
/// либо VK потребовал 2FA-код — какой канал отправлять.
class VkLkmpPasswordResult {
  final bool success;
  final String otpChannel; // sms | push | email — когда success == false
  final Map<String, dynamic> profile;

  const VkLkmpPasswordResult({
    required this.success,
    this.otpChannel = '',
    this.profile = const {},
  });
}

/// Пункт из ecosystem.getVerificationMethods (порт m1.C0450e).
class VkLkmpVerificationMethod {
  final String name;
  final String info;
  final int priority;
  final int timeout;

  const VkLkmpVerificationMethod({
    required this.name,
    required this.info,
    required this.priority,
    required this.timeout,
  });
}

// ---------------------------------------------------------------------------
// Сервис
// ---------------------------------------------------------------------------

class VkLkmpAuth {
  static const _clientId = '2274003';
  static const _clientSecret = 'hHbZxrka2uZ6jB1inYsH';
  static const _apiId = '2274003';
  static const _v = '5.276';
  static const _sak = '1.144.0';
  static const _flow = 'tg_flow';
  static const _flowNoPwd = 'auth_without_password';
  static const _host = 'https://api.vk.ru'; // НЕ .com и не oauth.vk.ru!

  /// Состояние как m1.C0448c (AuthInfo): заполняется по мере флоу.
  String sid = '';
  String login = '';
  String rememberHash = '';
  bool canSkipPassword = false;

  final http.Client _http;

  /// Cookie-хранилище: в LKMP это CookieManager(ACCEPT_ALL), подключённый к клиенту
  /// (N1_e.java:96-98). VK использует cookies для анти-фрода — запросы без cookie-истории
  /// чаще уводятся в капчу/флуд.
  final Map<String, String> _cookies = {};

  VkLkmpAuth(this._http);

  // -------------------------------------------------------------------------
  // Идентификаторы устройства (A.b.y, A.b.x, N1.e.g)
  // -------------------------------------------------------------------------

  /// LKMP: A.b.y() = android_id + ':' + MD5(Build.MODEL+Build.ID+MANUFACTURER+BRAND+TYPE+os.arch),
  /// где MD5 — с багом без ведущих нулей (Integer.toHexString(b & 255)). Хэш может быть
  /// короче 32 символов — это воспроизводится 1:1 и так и должно быть.
  String _lkmpMd5NoPad(String s) {
    final digest = md5.convert(s.codeUnits).bytes;
    return digest.map((b) => (b & 0xFF).toRadixString(16)).join();
  }

  Future<String> _deviceId() async {
    final p = await SharedPreferences.getInstance();
    final cached = p.getString('vk_lkmp_device_id');
    if (cached != null && cached.isNotEmpty) {
      final parts = cached.split(':');
      if (parts.length == 2 && parts[1].length >= 20) return cached;
      await p.remove('vk_lkmp_device_id');
    }
    final androidId = _randHex(16);
    // Fallback-набор как в A.b.x(): Google Nexus 5X + arm64-v8a
    const model = 'Google Nexus 5X';
    const id = 'TP1A.221105.002';
    const manufacturer = 'Google';
    const brand = 'google';
    const type = 'user';
    const arch = 'arm64-v8a';
    final dev = '$androidId:${_lkmpMd5NoPad(model + id + manufacturer + brand + type + arch)}';
    await p.setString('vk_lkmp_device_id', dev);
    return dev;
  }

  /// gaid — не настоящий Advertising ID, а случайный UUID 8-4-4-4-12 (N1.e.g(int)).
  String _gaid() {
    String g(int n) =>
        List.generate(n, (_) => '0123456789abcdef'[Random.secure().nextInt(16)]).join();
    return '${g(8)}-${g(4)}-${g(4)}-${g(4)}-${g(12)}';
  }

  Future<String> _gaidStored() async {
    final p = await SharedPreferences.getInstance();
    final g = p.getString('vk_lkmp_gaid');
    if (g != null && g.isNotEmpty) return g;
    final fresh = _gaid();
    await p.setString('vk_lkmp_gaid', fresh);
    return fresh;
  }

  /// A.b.x(): VKAndroidApp/8.175-51775 (Android <RELEASE>; SDK <SDK>; <arch>; <MODEL>; <lang>; WxH).
  /// При сбое в LKMP — константа 8.87-21014; здесь один динамический вариант.
  String _ua() =>
      'VKAndroidApp/8.175-51775 (Android 12; SDK 31; arm64-v8a;Google Nexus 5X; ru; 1920x1080)';

  String _randHex(int len) =>
      List.generate(len, (_) => '0123456789abcdef'[Random.secure().nextInt(16)]).join();

  // -------------------------------------------------------------------------
  // HTTP-конверт (N1.e.d): заголовки, cookie, gzip, ретраи
  // -------------------------------------------------------------------------

  /// Разбор Set-Cookie (порт M1.a): значения DELETED удаляют cookie.
  void _rememberCookies(String? raw) {
    if (raw == null || raw.isEmpty) return;
    // Делим по запятой ТОЛЬКО если дальше снова "name=" — чтобы не порвать Expires.
    final parts = raw.split(RegExp(r',(?=\s*[A-Za-z_][A-Za-z0-9_\-]*\s*=[^;])'));
    for (final part in parts) {
      final first = part.split(';').first.trim();
      final eq = first.indexOf('=');
      if (eq <= 0) continue;
      final name = first.substring(0, eq).trim();
      final value = first.substring(eq + 1).trim();
      if (name.isEmpty) continue;
      if (value == 'DELETED') {
        _cookies.remove(name);
        continue;
      }
      _cookies[name] = value;
    }
  }

  Map<String, String> _headers(String screen) => {
        if (screen.isNotEmpty) 'X-Screen': screen,
        'Cache-Control': 'no-cache',
        'Accept': 'image/webp',
        // и сам распаковывает ответ. Ручной заголовок приводил к бинарному r.body.
        'User-Agent': _ua(),
        'X-VK-Android-Client': 'new',
        'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
        if (_cookies.isNotEmpty)
          'Cookie': _cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
      };

  /// POST с разбором JSON и API-ошибок. Сетевые сбои ретраятся до 3 раз (N1.e.e()).
  Future<Map<String, dynamic>> _post(
    String url,
    Map<String, String> params,
    String screen,
  ) async {
    Object? lastErr;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final r = await _http
            .post(Uri.parse(url), headers: _headers(screen), body: params)
            .timeout(const Duration(seconds: 20));
        _rememberCookies(r.headers['set-cookie']);
        final text = r.body;
        if (text.isEmpty) {
          throw const VkLkmpAuthException(kind: 'network', message: 'Пустой ответ сервера');
        }
        final j = jsonDecode(text);
        if (j is Map<String, dynamic>) {
          final err = j['error'];
          if (err is Map<String, dynamic>) {
            final code = (err['error_code'] as num?)?.toInt() ?? 0;
            if (code == 14) {
              throw VkLkmpAuthException(
                kind: 'captcha',
                message: '${err['error_msg'] ?? 'Требуется капча'}',
                raw: j,
                captcha: VkLkmpCaptcha.fromMap(err),
              );
            }
            if (code == 9) {
              throw VkLkmpAuthException(
                kind: 'flood',
                message: '${err['error_msg'] ?? 'Flood control'}',
                raw: j,
              );
            }
            throw VkLkmpAuthException(
              kind: 'api',
              message: '${err['error_msg'] ?? err['error_text'] ?? 'API error'} (код $code)',
              raw: j,
            );
          }
          return j;
        }
        throw VkLkmpAuthException(
          kind: 'api',
          message: 'Неожиданный формат ответа',
          raw: {'body': text.substring(0, text.length > 400 ? 400 : text.length)},
        );
      } on VkLkmpAuthException {
        rethrow;
      } catch (e) {
        lastErr = e; // сеть/таймаут — повторяем
      }
    }
    throw VkLkmpAuthException(
        kind: 'network', message: 'Сетевая ошибка после 3 попыток: $lastErr');
  }

  /// Приставка капчи к параметрам — как в LKMP при повторном сабмите (README §7):
  /// captcha_sid, captcha_key, captcha_attempt=1, captcha_ts, is_sound_captcha=0.
  Map<String, String> _captchaParams(VkLkmpCaptcha c, String key) => {
        'captcha_sid': c.sid,
        'captcha_key': key,
        'captcha_attempt': '1',
        if (c.ts.isNotEmpty) 'captcha_ts': c.ts,
        'is_sound_captcha': '0',
      };

  // -------------------------------------------------------------------------
  // Аноним-токен (N1.e.b) с кешем на 55 минут (m1.f.c)
  // -------------------------------------------------------------------------

  String? _cachedAnon;
  int _anonTs = 0;

  Future<String> _cachedAnonToken() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_cachedAnon != null && now - _anonTs < 55 * 60 * 1000) return _cachedAnon!;
    return getAnonymToken();
  }

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
    final token = j['response'] is Map ? j['response']['token'] : null;
    if (token is String && token.isNotEmpty) {
      _cachedAnon = token;
      _anonTs = DateTime.now().millisecondsSinceEpoch;
      return token;
    }
    throw VkLkmpAuthException(
        kind: 'api', message: 'Ошибка получения аноним-токена', raw: j);
  }

  // -------------------------------------------------------------------------
  // Шаг 1: auth.validateAccount (m1.f.i)
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> validateAccount({
    required String phone,
    VkLkmpCaptcha? captcha,
    String captchaKey = '',
  }) async {
    login = phone;
    final anon = await _cachedAnonToken();
    final res = await _post('$_host/method/auth.validateAccount', {
      'login': phone,
      'access_token': anon,
      'supported_ways':
          'push,email,sms,callreset,password,reserve_code,codegen,official_messenger,max_code,passkey,libverify,max_messenger',
      'force_password': '0',
      'flow_type': _flowNoPwd,
      'sak_version': _sak,
      'gaid': await _gaidStored(),
      'device_id': await _deviceId(),
      'lang': 'ru',
      'v': _v,
      'https': '1',
      'api_id': _apiId,
      if (captcha != null && captchaKey.isNotEmpty) ..._captchaParams(captcha, captchaKey),
    }, 'auth_start_with_phone');
    final resp = res['response'];
    if (resp is Map) {
      if (resp['sid'] != null) sid = '${resp['sid']}';
      if (resp['remember_hash'] != null) rememberHash = '${resp['remember_hash']}';
    }
    return res;
  }

  // -------------------------------------------------------------------------
  // Шаг 2: ecosystem.sendOtpSms / sendOtpPush / sendOtpEmail (m1.f.f)
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> sendOtp({required String channel}) async {
    final method = switch (channel) {
      'push' => 'ecosystem.sendOtpPush',
      'email' => 'ecosystem.sendOtpEmail',
      _ => 'ecosystem.sendOtpSms',
    };
    final anon = await _cachedAnonToken();
    final res = await _post('$_host/method/$method', {
      'sid': sid,
      'access_token': anon,
      'lang': 'ru',
      'device_id': await _deviceId(),
      'sak_version': _sak,
      'flow_type': _flow,
      'gaid': await _gaidStored(),
      'v': _v,
      'https': '1',
      'api_id': _apiId,
    }, 'auth');
    final resp = res['response'];
    if (resp is Map && resp['sid'] != null) sid = '${resp['sid']}';
    return res;
  }

  // -------------------------------------------------------------------------
  // «Другой способ»: ecosystem.getVerificationMethods (N1.e.c)
  // Ответ: response.methods[] с полями info/priority/timeout/name
  // (B_RunnableC0023l0.java:127, m1.C0450e)
  // -------------------------------------------------------------------------

  Future<List<VkLkmpVerificationMethod>> getVerificationMethods() async {
    final anon = await _cachedAnonToken();
    final res = await _post('$_host/method/ecosystem.getVerificationMethods', {
      'sid': sid,
      'access_token': anon,
      'lang': 'ru',
      'device_id': await _deviceId(),
      'sak_version': _sak,
      'flow_type': _flow,
      'gaid': await _gaidStored(),
      'v': _v,
      'https': '1',
      'api_id': _apiId,
    }, 'auth');
    final resp = res['response'];
    final list = (resp is Map ? resp['methods'] : null) as List?;
    if (list == null) return const [];
    return list
        .whereType<Map>()
        .map((e) => VkLkmpVerificationMethod(
              name: '${e['name'] ?? ''}',
              info: '${e['info'] ?? ''}',
              priority: int.tryParse('${e['priority'] ?? ''}') ?? 0,
              timeout: int.tryParse('${e['timeout'] ?? ''}') ?? 0,
            ))
        .toList();
  }

  // -------------------------------------------------------------------------
  // Шаг 3: ecosystem.checkOtp (N1.e.a + g1_RunnableC0313D)
  // ВАЖНО: verification_method обязателен — без него VK отклоняет проверку.
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> checkOtp({
    required String code,
    required String verificationMethod,
    VkLkmpCaptcha? captcha,
    String captchaKey = '',
  }) async {
    final anon = await _cachedAnonToken();
    final res = await _post('$_host/method/ecosystem.checkOtp', {
      'sid': sid,
      'verification_method': verificationMethod,
      'code': code,
      'access_token': anon,
      'lang': 'ru',
      'device_id': await _deviceId(),
      'sak_version': _sak,
      'flow_type': _flow,
      'gaid': await _gaidStored(),
      'v': _v,
      'https': '1',
      'api_id': _apiId,
      if (captcha != null && captchaKey.isNotEmpty) ..._captchaParams(captcha, captchaKey),
    }, 'auth');
    final resp = res['response'];
    if (resp is Map) {
      if (resp['sid'] != null) sid = '${resp['sid']}';
      final skip = resp['can_skip_password'];
      canSkipPassword = skip == true || '$skip' == '1' || '$skip'.toLowerCase() == 'true';
    }
    return res;
  }

  // -------------------------------------------------------------------------
  // Шаг 4: oauth/token по паролю (m1.f.a)
  // ВАЖНО: grant_type=phone_confirmation_sid (НЕ password!), host api.vk.ru,
  // sid + anonymous_token + libverify_support + device_trusted_hash_supported.
  // -------------------------------------------------------------------------

  Future<VkLkmpPasswordResult> loginWithPassword({
    required String password,
    VkLkmpCaptcha? captcha,
    String captchaKey = '',
  }) async {
    final anon = await _cachedAnonToken();
    final res = await _post('$_host/oauth/token', {
      'sid': sid,
      'username': login,
      'password': password,
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
      if (captcha != null && captchaKey.isNotEmpty) ..._captchaParams(captcha, captchaKey),
    }, 'auth_password');

    // Ошибки oauth — строкой в корне ответа (не API-конверт): need_captcha,
    // need_validation, invalid_client (m1_f.a:100-140).
    final error = res['error'];
    if (error is String && error.isNotEmpty) {
      if (error == 'need_captcha') {
        throw VkLkmpAuthException(
          kind: 'captcha',
          message: 'Требуется капча',
          raw: res,
          captcha: VkLkmpCaptcha.fromMap(res),
        );
      }
      if (error == 'need_validation') {
        final vt = '${res['validation_type'] ?? ''}';
        final vsid = '${res['validation_sid'] ?? ''}';
        if (vsid.isNotEmpty) sid = vsid;
        // Как в LKMP: сами отправляем OTP нужным каналом и ведём на экран кода.
        if (vt == '2fa_sms' || vt == '2fa_push' || vt == '2fa_email') {
          final channel = vt == '2fa_sms' ? 'sms' : (vt == '2fa_push' ? 'push' : 'email');
          await sendOtp(channel: channel);
          return VkLkmpPasswordResult(success: false, otpChannel: channel);
        }
        throw VkLkmpAuthException(
          kind: 'need_validation',
          message: '${res['error_description'] ?? vt}',
          raw: res,
          validationType: vt,
        );
      }
      if (error == 'invalid_client') {
        throw VkLkmpAuthException(
          kind: 'invalid_client',
          message: '${res['error_description'] ?? 'Неверный логин или пароль'}',
          raw: res,
        );
      }
      throw VkLkmpAuthException(
        kind: 'api',
        message: '${res['error_description'] ?? error}',
        raw: res,
      );
    }
    if (res['access_token'] == null) {
      throw VkLkmpAuthException(
          kind: 'api', message: 'oauth/token: нет access_token в ответе', raw: res);
    }
    final profile = await postLogin((res).cast<String, dynamic>());
    return VkLkmpPasswordResult(success: true, profile: profile);
  }

  // -------------------------------------------------------------------------
  // Шаг 5: пост-логин (m1.f.b) — обязателен после получения access_token
  // -------------------------------------------------------------------------

  /// Общий вызов метода API (N1_b.java case 0): access_token сессии + lang/v/https/device_id,
  /// БЕЗ X-Screen. При error_code 1117 — обмен exchange-токена и повтор (до 3 раз).
  Future<Map<String, dynamic>> _apiCall(
    String method,
    Map<String, String> params,
    String token,
  ) async {
    var current = token;
    for (var attempt = 0; attempt < 3; attempt++) {
      final res = await _post('$_host/method/$method', {
        ...params,
        'access_token': current,
        'lang': 'ru',
        'v': _v,
        'https': '1',
        'device_id': await _deviceId(),
      }, '');
      final err = res['error'];
      if (err is Map<String, dynamic> && (err['error_code'] as num?)?.toInt() == 1117) {
        final fresh = await refreshByExchangeToken();
        if (fresh == null) {
          throw VkLkmpAuthException(
              kind: 'api', message: 'Токен истёк (1117), exchange-токена нет', raw: res);
        }
        current = fresh;
        continue;
      }
      return res;
    }
    throw const VkLkmpAuthException(kind: 'api', message: 'Исчерпаны повторы запроса');
  }

  /// Пост-логин: execute.getUserInfo (func_v=33, needExchangeToken=1) → exchange_token,
  /// auth.refreshToken (ответ не используется, но запрос обязателен),
  /// account.getProfileInfo → профиль. Сохраняет сессию (q.V: token/user_id/exchange_token).
  Future<Map<String, dynamic>> postLogin(Map<String, dynamic> tokenJson) async {
    final token = '${tokenJson['access_token'] ?? tokenJson['token'] ?? ''}';
    if (token.isEmpty) {
      throw const VkLkmpAuthException(kind: 'api', message: 'Пустой access_token');
    }
    final userIdRaw = '${tokenJson['user_id'] ?? ''}';

    var exchangeToken = '';
    Map<String, dynamic> profile = {};
    try {
      final ui = await _apiCall('execute.getUserInfo', {
        'func_v': '33',
        'needExchangeToken': '1',
      }, token);
      final resp = ui['response'];
      if (resp is Map && resp['exchange_token'] != null) {
        exchangeToken = '${resp['exchange_token']}';
      }
    } on VkLkmpAuthException {
      rethrow;
    }
    try {
      await _apiCall('auth.refreshToken', const {}, token);
    } on VkLkmpAuthException catch (_) {
      // LKMP игнорирует результат refreshToken
    }
    try {
      final pr = await _apiCall('account.getProfileInfo', const {}, token);
      if (pr['response'] is Map) profile = (pr['response'] as Map).cast<String, dynamic>();
    } on VkLkmpAuthException catch (_) {
      // профиль не критичен для входа
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vk_music_token', token);
    final uid = int.tryParse(userIdRaw) ?? int.tryParse('${profile['id'] ?? ''}') ?? 0;
    if (uid != 0) await prefs.setInt('vk_music_uid', uid);
    if (exchangeToken.isNotEmpty) await prefs.setString('vk_exchange_token', exchangeToken);
    return profile;
  }

  // -------------------------------------------------------------------------
  // Обновление токена (N1.e.h): oauth/auth_by_exchange_token
  // Ответ приходит ФРАГМЕНТОМ URL "#access_token=...&..." (N1_e.java:346-356),
  // а не JSON — прежний порт всегда возвращал null.
  // -------------------------------------------------------------------------

  Future<String?> refreshByExchangeToken() async {
    final prefs = await SharedPreferences.getInstance();
    final ex =
        prefs.getString('vk_exchange_token') ?? prefs.getString('vk_lkmp_exchange') ?? '';
    if (ex.isEmpty) return null;

    final body = {
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
    };
    final raw = await _postCaptureRedirect('$_host/oauth/auth_by_exchange_token', body);

    // Парс "#key=value&..." как в N1_e.h
    String source = raw;
    final hashIdx = source.indexOf('#');
    if (hashIdx >= 0) source = source.substring(hashIdx + 1);
    final parsed = <String, String>{};
    for (final pair in source.split('&')) {
      final i = pair.indexOf('=');
      if (i <= 0) continue;
      parsed[pair.substring(0, i).trim()] = Uri.decodeComponent(pair.substring(i + 1).trim());
    }
    // Fallback: иногда может прийти обычный JSON
    if (!parsed.containsKey('access_token')) {
      try {
        final j = jsonDecode(raw);
        if (j is Map) {
          final t = j['access_token'] ?? j['token'];
          if (t != null) parsed['access_token'] = '$t';
          if (j['exchange_token'] != null) parsed['exchange_token'] = '${j['exchange_token']}';
          if (j['user_id'] != null) parsed['user_id'] = '${j['user_id']}';
        }
      } catch (_) {}
    }

    final token = parsed['access_token'];
    if (token == null || token.isEmpty) return null;
    await prefs.setString('vk_music_token', token);
    if (parsed['exchange_token'] != null && parsed['exchange_token']!.isNotEmpty) {
      await prefs.setString('vk_exchange_token', parsed['exchange_token']!);
    }
    final uid = int.tryParse(parsed['user_id'] ?? '');
    if (uid != null) await prefs.setInt('vk_music_uid', uid);
    return token;
  }

  /// POST без следования редиректам: auth_by_exchange_token отвечает 302 с
  /// Location: ...#access_token=... — именно фрагмент и нужно забрать.
  Future<String> _postCaptureRedirect(String url, Map<String, String> body) async {
    final hc = HttpClient()..autoRedirect = false;
    try {
      final req = await hc.openUrl('POST', Uri.parse(url));
      req.headers.set(HttpHeaders.contentTypeHeader,
          'application/x-www-form-urlencoded; charset=utf-8');
      req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      req.headers.set('Accept', 'image/webp');
      req.headers.set(HttpHeaders.userAgentHeader, _ua());
      req.headers.set('X-VK-Android-Client', 'new');
      req.headers.set('X-Screen', 'auth_password');
      if (_cookies.isNotEmpty) {
        req.headers.set(HttpHeaders.cookieHeader,
            _cookies.entries.map((e) => '${e.key}=${e.value}').join('; '));
      }
      final encoded =
          body.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
      req.add(utf8.encode(encoded));
      final resp = await req.close();
      _rememberCookies(resp.headers.value(HttpHeaders.setCookieHeader));
      final text = await utf8.decodeStream(resp);
      final loc = resp.headers.value(HttpHeaders.locationHeader) ?? '';
      if (loc.contains('#')) return loc.substring(loc.indexOf('#'));
      if (text.contains('#access_token')) return text.substring(text.indexOf('#'));
      return text;
    } finally {
      hc.close(force: true);
    }
  }
}
