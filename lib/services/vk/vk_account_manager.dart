import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'vk_api.dart';
import 'vk_auth_core.dart';

/// Порт VkAccountManager.kt на Dart (без EncryptedSharedPreferences,
/// используем SharedPreferences — при желании заменить на flutter_secure_storage).
class VkAccountManager {
  static const _prefsName = 'vk_account_state_secure';
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kExpiresAt = 'expires_at_ms';
  static const _kUserId = 'user_id';
  static const _kDeviceId = 'device_id';
  static const _kPendingState = 'pending_state';
  static const _kPendingVerifier = 'pending_verifier';

  static const _ua = 'VKAndroidApp/8.12 (Android 11; SDK 30; arm64-v8a; ru; com.vkontakte.android)';

  final http.Client _http;
  VkAccountManager(this._http);

  VkAuthSession? _session;
  VkAuthSession? get session => _session;

  Future<void> restore(SharedPreferences prefs) async {
    final access = prefs.getString(_kAccess) ?? '';
    if (access.isEmpty) return;
    _session = VkAuthSession(
      accessToken: access,
      refreshToken: prefs.getString(_kRefresh) ?? '',
      expiresAtMs: prefs.getInt(_kExpiresAt) ?? 0,
      userId: prefs.getInt(_kUserId) ?? 0,
      deviceId: await getDeviceId(prefs),
    );
  }

  Future<String> getDeviceId(SharedPreferences prefs) async {
    var id = prefs.getString(_kDeviceId);
    if (id == null || id.isEmpty) {
      id = VkAuthCore.generateDeviceId();
      await prefs.setString(_kDeviceId, id);
    }
    return id;
  }

  String? currentToken() => _session?.accessToken.isNotEmpty == true ? _session!.accessToken : null;

  /// Шаг 1: verifier/state + URL для WebView
  Future<({String authorizeUrl, String state})> startLogin(
    SharedPreferences prefs, {
    int langId = 0,
    String scheme = 'space_gray',
  }) async {
    final verifier = VkAuthCore.generateCodeVerifier();
    final challenge = VkAuthCore.generateCodeChallenge(verifier);
    final state = VkAuthCore.generateState();
    await prefs.setString(_kPendingVerifier, verifier);
    await prefs.setString(_kPendingState, state);
    final url = VkApi.oauthAuthorizeUrl(
      codeChallenge: challenge,
      state: state,
      langId: langId,
      scheme: scheme,
    );
    return (authorizeUrl: url, state: state);
  }

  /// Шаг 3-4: intercept redirect -> обмен кода на токен
  Future<String?> handleRedirect(String redirectUrl, SharedPreferences prefs) async {
    final parsed = VkAuthCore.parseRedirect(redirectUrl);
    if (parsed == null) return 'Это не redirect авторизации VK';
    final expectedState = prefs.getString(_kPendingState) ?? '';
    if (!VkAuthCore.validateState(expectedState, parsed.state)) {
      return 'Подмена redirect: state не совпал';
    }
    final verifier = prefs.getString(_kPendingVerifier) ?? '';
    if (verifier.isEmpty) return 'Потерян PKCE-verifier, начните вход заново';

    final deviceId = (parsed.deviceId?.isNotEmpty == true) ? parsed.deviceId! : await getDeviceId(prefs);

    try {
      final body = VkApi.oauthExchangeBody(
        code: parsed.code,
        codeVerifier: verifier,
        state: parsed.state,
        deviceId: deviceId,
      );
      final json = await _executeOauth(body);
      await _storeSession(json, deviceId, prefs);
      await prefs.remove(_kPendingVerifier);
      await prefs.remove(_kPendingState);
      return null;
    } catch (e) {
      return 'Ошибка обмена кода: $e';
    }
  }

  Future<String?> refresh(SharedPreferences prefs) async {
    final s = _session;
    if (s == null) return 'Нет сессии VK';
    if (s.refreshToken.isEmpty) return 'Нет refresh-токена, нужен повторный вход';
    try {
      final body = VkApi.oauthRefreshBody(
        refreshToken: s.refreshToken,
        deviceId: s.deviceId,
        state: VkAuthCore.generateState(),
      );
      final json = await _executeOauth(body);
      await _storeSession(json, s.deviceId, prefs);
      return null;
    } catch (e) {
      return 'Ошибка обновления сессии: $e';
    }
  }

  Future<void> logout(SharedPreferences prefs) async {
    final s = _session;
    _session = null;
    await prefs.clear();
    if (s != null) {
      try {
        await _http.post(
          Uri.parse(VkApi.hostOAuthLogout),
          headers: {'User-Agent': _ua},
          body: {'client_id': VkApi.oauthClientId, 'access_token': s.accessToken},
        );
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> _executeOauth(Map<String, String> body) async {
    final resp = await _http.post(
      Uri.parse(VkApi.hostOAuthToken),
      headers: {'User-Agent': _ua},
      body: body,
    );
    final text = resp.body;
    final json = text.isEmpty ? <String, dynamic>{} : jsonDecode(text) as Map<String, dynamic>;
    if (json.containsKey('error')) {
      throw Exception('VK ID: ${json['error']}: ${json['error_description']}');
    }
    if (!json.containsKey('access_token')) {
      throw Exception('VK ID: нет access_token в ответе');
    }
    return json;
  }

  Future<void> _storeSession(Map<String, dynamic> json, String deviceId, SharedPreferences prefs) async {
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
    final s = VkAuthSession(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String? ?? '',
      expiresAtMs: DateTime.now().millisecondsSinceEpoch + expiresIn * 1000,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      deviceId: deviceId,
    );
    await prefs.setString(_kAccess, s.accessToken);
    await prefs.setString(_kRefresh, s.refreshToken);
    await prefs.setInt(_kExpiresAt, s.expiresAtMs);
    await prefs.setInt(_kUserId, s.userId);
    await prefs.setString(_kDeviceId, s.deviceId);
    _session = s;
  }
}
