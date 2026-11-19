import 'dart:convert';
import 'package:http/http.dart' as http;

/// Порт Go-пакета oklookat/vkmauth на Dart.
/// Поток: getAnonymousToken → validatePhone → validatePhoneConfirm → getSilentToken → checkSilentToken → getToken (moosic)
/// Константы взяты из vkmauth/main.go.
class VkIdAuth {
  static const _clientId = '6767438';
  static const _clientSecret = 'ppBOmwQYYOMGulmaiPyK';
  static const _apiId = _clientId;
  static const _apiVersion = '5.209';
  static const _sakVersion = '1.107';
  static const _vkApiUrl = 'https://api.vk.com';
  static const _vkOAuthUrl = '$_vkApiUrl/oauth';
  static const _moosicTokenUrl = 'https://api.moosic.io/oauth/vkconnect/vk/token';
  static const _ua = 'SAK_1.107(com.uma.musicvk)/6.1.229-10477';

  final http.Client _http;
  VkIdAuth(this._http);

  Map<String, String> _headers() => {'User-Agent': _ua};

  /// 1. getAnonymousToken
  Future<_AnonToken> getAnonymousToken(String deviceId) async {
    final uri = Uri.parse('$_vkOAuthUrl/get_anonym_token');
    final r = await _http.post(uri, headers: _headers(), body: {
      'client_id': _clientId,
      'client_secret': _clientSecret,
      'device_id': deviceId,
      'api_id': _apiId,
    });
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if (j.containsKey('error')) throw VkIdException('getAnonymousToken', j);
    if (r.statusCode != 200) throw VkIdException('getAnonymousToken HTTP ${r.statusCode}', j);
    return _AnonToken(token: j['token'] as String, expiredAt: (j['expired_at'] as num).toInt(), deviceId: deviceId);
  }

  /// 2. validatePhone
  Future<_ValidatePhoneResp> validatePhone({required String phone, required String sid, required _AnonToken anon}) async {
    final uri = Uri.parse('$_vkApiUrl/method/auth.validatePhone');
    final body = <String, String>{
      'access_token': anon.token,
      'device_id': anon.deviceId,
      'phone': phone,
      'supported_ways': 'push,email',
      'sak_version': _sakVersion,
      'v': _apiVersion,
      'api_id': _apiId,
      if (sid.isNotEmpty) 'sid': sid,
    };
    final r = await _http.post(uri, headers: _headers(), body: body);
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if (j['error'] != null) throw VkIdException('validatePhone', j['error'] is Map ? j['error'] : j);
    if (r.statusCode != 200) throw VkIdException('validatePhone HTTP ${r.statusCode}', j);
    final resp = j['response'] as Map<String, dynamic>?;
    if (resp == null) throw VkIdException('validatePhone empty response', j);
    return _ValidatePhoneResp(
      sid: resp['sid'] as String? ?? '',
      type: resp['type'] as String? ?? '',
      delay: (resp['delay'] as num?)?.toInt() ?? 0,
      validationType: resp['validation_type'] as String? ?? '',
      validationResend: resp['validation_resend'] as String? ?? '',
      codeLength: (resp['code_length'] as num?)?.toInt() ?? 4,
    );
  }

  /// 3. validatePhoneConfirm
  Future<_ValidateConfirmResp> validatePhoneConfirm({
    required String deviceId,
    required String code,
    required String phone,
    required String anonToken,
    required String sid,
  }) async {
    final uri = Uri.parse('$_vkApiUrl/method/auth.validatePhoneConfirm');
    final body = <String, String>{
      'access_token': anonToken,
      'code': code,
      'phone': phone,
      'device_id': deviceId,
      'sak_version': _sakVersion,
      'can_skip_password': '0',
      'v': _apiVersion,
      'api_id': _apiId,
      'sid': sid,
    };
    final r = await _http.post(uri, headers: _headers(), body: body);
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if (j['error'] != null) throw VkIdException('validatePhoneConfirm', j['error'] is Map ? j['error'] : j);
    if (r.statusCode != 200) throw VkIdException('validatePhoneConfirm HTTP ${r.statusCode}', j);
    final resp = j['response'] as Map<String, dynamic>;
    return _ValidateConfirmResp(
      sid: resp['sid'] as String? ?? '',
      profileExist: resp['profile_exist'] as bool? ?? false,
      has2Fa: (resp['profile'] as Map?)?['has_2fa'] as bool? ?? false,
      raw: resp,
    );
  }

  /// 4. getSilentToken
  Future<_SilentToken> getSilentToken({
    required String sid,
    required String phone,
    required String password,
    required String anonymousToken,
    required String deviceId,
    required bool twoFaSupported,
  }) async {
    final uri = Uri.parse('$_vkOAuthUrl/token');
    final body = <String, String>{
      'sid': sid,
      'grant_type': 'phone_confirmation_sid',
      'username': phone,
      'password': password,
      '2fa_supported': twoFaSupported ? '1' : '0',
      'supported_ways': 'push,email',
      'anonymous_token': anonymousToken,
      'device_id': deviceId,
      'v': _apiVersion,
      'api_id': _apiId,
      'sak_version': _sakVersion,
    };
    final r = await _http.post(uri, headers: _headers(), body: body);
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200) throw VkIdException('getSilentToken HTTP ${r.statusCode}', j);
    if (j['error'] != null) throw VkIdException('getSilentToken', j);
    // может вернуться ошибка в виде error_description
    if (!j.containsKey('silent_token')) throw VkIdException('getSilentToken no silent_token', j);
    return _SilentToken(
      token: j['silent_token'] as String,
      uuid: j['silent_token_uuid'] as String,
      ttl: (j['silent_token_ttl'] as num?)?.toInt() ?? 0,
      trustedHash: j['trusted_hash'] as String? ?? '',
    );
  }

  /// 5. checkSilentToken
  Future<_SilentToken> checkSilentToken({required String token, required String uuid, required String anonToken, required String deviceId}) async {
    final uri = Uri.parse('$_vkOAuthUrl/check_silent_token');
    final body = <String, String>{
      'token': token,
      'uuid': uuid,
      'anonymous_token': anonToken,
      'v': _apiVersion,
      'device_id': deviceId,
      'api_id': _apiId,
      'sak_version': _sakVersion,
    };
    final r = await _http.post(uri, headers: _headers(), body: body);
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200) throw VkIdException('checkSilentToken HTTP ${r.statusCode}', j);
    if (j['error'] != null) throw VkIdException('checkSilentToken', j);
    return _SilentToken(token: j['silent_token'] as String, uuid: j['silent_token_uuid'] as String, ttl: (j['silent_token_ttl'] as num?)?.toInt() ?? 0, trustedHash: '');
  }

  /// 6. getToken (moosic) → финальный access_token для музыки
  Future<_FinalToken> getToken({required String deviceId, required String uuid, required String silentToken}) async {
    final uri = Uri.parse(_moosicTokenUrl).replace(queryParameters: {
      'device_id': deviceId,
      'device_os': 'android',
      'uuid': uuid,
      'silent_token': silentToken,
    });
    final r = await _http.get(uri, headers: _headers());
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200) throw VkIdException('getToken moosic HTTP ${r.statusCode}', j);
    if (j['error'] != null) throw VkIdException('getToken moosic', j);
    if (!j.containsKey('access_token')) throw VkIdException('getToken no access_token', j);
    return _FinalToken(
      accessToken: j['access_token'] as String,
      expiresIn: (j['expires_in'] as num).toInt(),
      refreshToken: j['refresh_token'] as String? ?? '',
    );
  }

  /// Высокоуровневый хелпер: телефон → код → пароль → токен
  /// onCodeWait вызывается после validatePhone, должен вернуть код (и resend=false).
  Future<_FinalToken> authWithPhone({
    required String phone,
    required String password,
    required Future<String> Function(_ValidatePhoneResp info) onCodeWait,
    String? deviceIdOverride,
  }) async {
    final deviceId = deviceIdOverride ?? _genDeviceId();
    final anon = await getAnonymousToken(deviceId);
    _ValidatePhoneResp? valResp;
    String sid = '';
    String code = '';
    // цикл resend (обычно 1 итерация)
    bool resend = true;
    while (resend) {
      valResp = await validatePhone(phone: phone, sid: sid, anon: anon);
      sid = valResp.sid;
      final wantResend = await onCodeWait(valResp);
      // onCodeWait возвращает код, resend=false; если нужно resend — вернёт пустой код + логика снаружи
      // Упрощаем: считаем что код уже есть, resend=false
      code = wantResend;
      if (code.isEmpty) throw VkIdException('authWithPhone empty code', {'sid': sid});
      resend = false;
    }
    final confirm = await validatePhoneConfirm(deviceId: deviceId, code: code, phone: phone, anonToken: anon.token, sid: sid);
    final silent = await getSilentToken(sid: confirm.sid, phone: phone, password: password, anonymousToken: anon.token, deviceId: deviceId, twoFaSupported: confirm.has2Fa);
    final checked = await checkSilentToken(token: silent.token, uuid: silent.uuid, anonToken: anon.token, deviceId: deviceId);
    final finalTok = await getToken(deviceId: deviceId, uuid: checked.uuid, silentToken: checked.token);
    return finalTok;
  }

  String _genDeviceId() {
    // ulid-like: просто uuid v4 без дефисов + timestamp
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = (now % 1000000).toString().padLeft(6, '0');
    return 'aura_${now}_$rand';
  }
}

class _AnonToken {
  final String token;
  final int expiredAt;
  final String deviceId;
  _AnonToken({required this.token, required this.expiredAt, required this.deviceId});
}

class _ValidatePhoneResp {
  final String sid;
  final String type;
  final int delay;
  final String validationType;
  final String validationResend;
  final int codeLength;
  _ValidatePhoneResp({required this.sid, required this.type, required this.delay, required this.validationType, required this.validationResend, required this.codeLength});
}

class _ValidateConfirmResp {
  final String sid;
  final bool profileExist;
  final bool has2Fa;
  final Map<String, dynamic> raw;
  _ValidateConfirmResp({required this.sid, required this.profileExist, required this.has2Fa, required this.raw});
}

class _SilentToken {
  final String token;
  final String uuid;
  final int ttl;
  final String trustedHash;
  _SilentToken({required this.token, required this.uuid, required this.ttl, required this.trustedHash});
}

class _FinalToken {
  final String accessToken;
  final int expiresIn;
  final String refreshToken;
  _FinalToken({required this.accessToken, required this.expiresIn, required this.refreshToken});
}

class VkIdException implements Exception {
  final String step;
  final dynamic payload;
  VkIdException(this.step, this.payload);
  @override
  String toString() => 'VkId $step: $payload';
}
