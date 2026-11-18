import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'vk_api.dart';
import 'vk_auth_core.dart';

/// Порт VkAccountManager.kt — логика 1в1, только SharedPreferences вместо EncryptedSharedPreferences.
class VkAccountManager {
  static const _prefsName = 'vk_account_state_secure';
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kExpires = 'expires_at_ms';
  static const _kUserId = 'user_id';
  static const _kDeviceId = 'device_id';
  static const _kPendingState = 'pending_state';
  static const _kPendingVerifier = 'pending_verifier';

  static const _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/150.0.0.0 Safari/537.36';

  /// HTTP-клиент по умолчанию (vk_auth_page создаёт VkAccountManager(http.Client()))
  final http.Client? _injectedClient;

  VkAccountManager([this._injectedClient]);

  VkAuthSession? _session;
  VkAuthSession? get session => _session;

  Future<void> restore([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final access = p.getString('vk_account_state_secure_$_kAccess') ?? '';
    if (access.isEmpty) return;
    _session = VkAuthSession(
      accessToken: access,
      refreshToken: p.getString('vk_account_state_secure_$_kRefresh') ?? '',
      expiresAtMs: p.getInt('vk_account_state_secure_$_kExpires') ?? 0,
      userId: p.getInt('vk_account_state_secure_$_kUserId') ?? 0,
      deviceId: await getDeviceId(),
    );
  }

  Future<String> getDeviceId() async {
    final p = await SharedPreferences.getInstance();
    var id = p.getString('vk_account_state_secure_$_kDeviceId');
    if (id == null || id.isEmpty) {
      id = VkAuthCore.generateDeviceId();
      await p.setString('vk_account_state_secure_$_kDeviceId', id);
    }
    return id;
  }

  String? currentToken() => _session?.accessToken.isNotEmpty == true ? _session!.accessToken : null;

  Future<({String authorizeUrl, String state})> startLogin({int langId = 0, String scheme = 'space_gray', SharedPreferences? prefs, String? clientIdOverride}) async {
    final verifier = VkAuthCore.generateCodeVerifier();
    final challenge = VkAuthCore.generateCodeChallenge(verifier);
    final state = VkAuthCore.generateState();
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString('vk_account_state_secure_$_kPendingVerifier', verifier);
    await p.setString('vk_account_state_secure_$_kPendingState', state);
    final url = VkApi.oauthAuthorizeUrl(codeChallenge: challenge, state: state, langId: langId, scheme: scheme, clientId: clientIdOverride ?? VkApi.oauthClientId);
    return (authorizeUrl: url, state: state);
  }

  /// Перехваченный redirect → обмен кода на токен. null = успех, иначе текст ошибки.
  Future<String?> handleRedirect(String redirectUrl, {http.Client? client, SharedPreferences? prefs}) async {
    final parsed = VkAuthCore.parseRedirect(redirectUrl);
    if (parsed == null) return 'Это не redirect авторизации VK';
    final p = prefs ?? await SharedPreferences.getInstance();
    final expected = p.getString('vk_account_state_secure_$_kPendingState') ?? '';
    if (!VkAuthCore.validateState(expected, parsed.state)) return 'Подмена redirect: state не совпал';
    final verifier = p.getString('vk_account_state_secure_$_kPendingVerifier') ?? '';
    if (verifier.isEmpty) return 'Потерян PKCE-verifier, начните вход заново';
    final deviceId = (parsed.deviceId?.isNotEmpty == true) ? parsed.deviceId! : await getDeviceId();
    try {
      final body = VkApi.oauthExchangeBody(code: parsed.code, codeVerifier: verifier, state: parsed.state, deviceId: deviceId);
      final json = await _executeOauth(body, client: client);
      await _storeSession(json, deviceId);
      await p.remove('vk_account_state_secure_$_kPendingVerifier');
      await p.remove('vk_account_state_secure_$_kPendingState');
      return null;
    } catch (e) {
      return 'Ошибка обмена кода: $e';
    }
  }

  Future<String?> refresh({http.Client? client}) async {
    final s = _session;
    if (s == null) return 'Нет сессии VK';
    if (s.refreshToken.isEmpty) return 'Нет refresh-токена, нужен повторный вход';
    try {
      final body = VkApi.oauthRefreshBody(refreshToken: s.refreshToken, deviceId: s.deviceId, state: VkAuthCore.generateState());
      final json = await _executeOauth(body, client: client);
      await _storeSession(json, s.deviceId);
      return null;
    } catch (e) {
      return 'Ошибка обновления сессии: $e';
    }
  }

  Future<void> logout({http.Client? client}) async {
    final s = _session;
    _session = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('vk_account_state_secure_$_kAccess');
    await p.remove('vk_account_state_secure_$_kRefresh');
    await p.remove('vk_account_state_secure_$_kExpires');
    await p.remove('vk_account_state_secure_$_kUserId');
    if (s != null) {
      try {
        final c = client ?? _injectedClient ?? http.Client();
        await c.post(Uri.parse(VkApi.hostOAuthLogout), headers: {'User-Agent': _userAgent}, body: {'client_id': VkApi.oauthClientId, 'access_token': s.accessToken}).timeout(const Duration(seconds: 8));
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> _executeOauth(Map<String, String> body, {http.Client? client}) async {
    final c = client ?? _injectedClient ?? http.Client();
    final resp = await c.post(Uri.parse(VkApi.hostOAuthToken), headers: {'User-Agent': _userAgent}, body: body).timeout(const Duration(seconds: 12));
    final text = resp.body;
    final json = text.isEmpty ? <String, dynamic>{} : jsonDecode(text) as Map<String, dynamic>;
    if (json.containsKey('error')) throw Exception('VK ID: ${json['error']}: ${json['error_description']}');
    if (!json.containsKey('access_token')) throw Exception('VK ID: нет access_token в ответе');
    return json.cast<String, dynamic>();
  }

  Future<void> _storeSession(Map<String, dynamic> json, String deviceId) async {
    final expiresIn = (json['expires_in'] as int?) ?? 3600;
    final s = VkAuthSession(
      accessToken: (json['access_token'] ?? '').toString(),
      refreshToken: (json['refresh_token'] ?? '').toString(),
      expiresAtMs: DateTime.now().millisecondsSinceEpoch + expiresIn * 1000,
      userId: (json['user_id'] as int?) ?? int.tryParse('${json['user_id']}') ?? 0,
      deviceId: deviceId,
    );
    final p = await SharedPreferences.getInstance();
    await p.setString('vk_account_state_secure_$_kAccess', s.accessToken);
    await p.setString('vk_account_state_secure_$_kRefresh', s.refreshToken);
    await p.setInt('vk_account_state_secure_$_kExpires', s.expiresAtMs);
    await p.setInt('vk_account_state_secure_$_kUserId', s.userId);
    await p.setString('vk_account_state_secure_$_kDeviceId', s.deviceId);
    // дубль для старого кода
    await p.setString('vk_music_token', s.accessToken);
    _session = s;
  }
}
