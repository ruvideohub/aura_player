import 'dart:convert';
import 'package:http/http.dart' as http;

/// Порт oklookat/vkmauth + vk.com site client (6287487/QbYic1K3lEV5kTGiqlq2)
/// Поток: getAnonymousToken → validatePhone → validatePhoneConfirm → getSilentToken → checkSilentToken → getToken (moosic)
class VkIdAuth {
  // VK site (vk.com) — не блочится, рекомендован как замена Kate после 2024-06-25
  static const _clientId = '6287487';
  static const _clientSecret = 'QbYic1K3lEV5kTGiqlq2';
  static const _apiId = _clientId;
  static const _apiVersion = '5.209';
  static const _sakVersion = '1.107';
  static const _vkApiUrl = 'https://api.vk.com';
  static const _vkOAuthUrl = '$_vkApiUrl/oauth';
  static const _moosicTokenUrl = 'https://api.moosic.io/oauth/vkconnect/vk/token';
  // Fallback для site-id: обычный VK UA тоже проходит
  static const _ua = 'SAK_1.107(com.uma.musicvk)/6.1.229-10477';

  final http.Client _http;
  VkIdAuth(this._http);

  Map<String, String> _headers() => {'User-Agent': _ua};

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
    if (!j.containsKey('silent_token')) throw VkIdException('getSilentToken no silent_token', j);
    return _SilentToken(
      token: j['silent_token'] as String,
      uuid: j['silent_token_uuid'] as String,
      ttl: (j['silent_token_ttl'] as num?)?.toInt() ?? 0,
      trustedHash: j['trusted_hash'] as String? ?? '',
    );
  }

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

  String _genDeviceId() {
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
