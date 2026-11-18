import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class VkAuthSession {
  final String accessToken;
  final String refreshToken;
  final int expiresAtMs;
  final int userId;
  final String deviceId;

  const VkAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAtMs,
    required this.userId,
    required this.deviceId,
  });

  bool isActive([int? nowMs]) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return accessToken.isNotEmpty && now < expiresAtMs;
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_at_ms': expiresAtMs,
        'user_id': userId,
        'device_id': deviceId,
      };

  factory VkAuthSession.fromJson(Map<String, dynamic> j) => VkAuthSession(
        accessToken: j['access_token'] as String? ?? '',
        refreshToken: j['refresh_token'] as String? ?? '',
        expiresAtMs: (j['expires_at_ms'] as num?)?.toInt() ?? 0,
        userId: (j['user_id'] as num?)?.toInt() ?? 0,
        deviceId: j['device_id'] as String? ?? '',
      );
}

class VkAuthCore {
  static const _verifierAlphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
  static const _verifierLength = 128;

  static const _b64url = [
    'A','B','C','D','E','F','G','H','I','J','K','L','M',
    'N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
    'a','b','c','d','e','f','g','h','i','j','k','l','m',
    'n','o','p','q','r','s','t','u','v','w','x','y','z',
    '0','1','2','3','4','5','6','7','8','9','-','_',
  ];

  static String generateCodeVerifier([Random? random]) {
    random ??= Random.secure();
    final sb = StringBuffer();
    for (int i = 0; i < _verifierLength; i++) {
      sb.write(_verifierAlphabet[random.nextInt(_verifierAlphabet.length)]);
    }
    return sb.toString();
  }

  static String generateCodeChallenge(String verifier) {
    final hash = sha256.convert(verifier.codeUnits).bytes;
    return base64UrlNoPad(Uint8List.fromList(hash));
  }

  static String generateState([Random? random]) {
    random ??= Random.secure();
    final bytes = Uint8List(16);
    for (int i = 0; i < 16; i++) bytes[i] = random.nextInt(256);
    return base64UrlNoPad(bytes);
  }

  static String generateDeviceId([Random? random]) {
    random ??= Random.secure();
    final bytes = Uint8List(16);
    for (int i = 0; i < 16; i++) bytes[i] = random.nextInt(256);
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Разбор redirect `blank.html?code=..&state=..&device_id=..`
  /// Возвращает null если не финальный redirect.
  static ({String code, String state, String? deviceId})? parseRedirect(String url) {
    if (!url.contains('blank.html') && !url.contains('oauth.vk.')) return null;
    final qIdx = url.indexOf('?');
    if (qIdx < 0) return null;
    final query = url.substring(qIdx + 1);
    if (query.isEmpty) return null;
    String? code, state, deviceId;
    for (final pair in query.split('&')) {
      final idx = pair.indexOf('=');
      if (idx <= 0) continue;
      final k = pair.substring(0, idx);
      final v = Uri.decodeComponent(pair.substring(idx + 1));
      switch (k) {
        case 'code':
          code = v;
          break;
        case 'state':
          state = v;
          break;
        case 'device_id':
          deviceId = v;
          break;
      }
    }
    if (code == null) return null;
    return (code: code, state: state ?? '', deviceId: deviceId);
  }

  static bool validateState(String expected, String received) =>
      expected.isNotEmpty && received == expected;

  static String base64UrlNoPad(Uint8List bytes) {
    final sb = StringBuffer();
    int i = 0;
    while (i + 2 < bytes.length) {
      final chunk = (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2];
      sb.write(_b64url[(chunk >> 18) & 0x3F]);
      sb.write(_b64url[(chunk >> 12) & 0x3F]);
      sb.write(_b64url[(chunk >> 6) & 0x3F]);
      sb.write(_b64url[chunk & 0x3F]);
      i += 3;
    }
    final rest = bytes.length - i;
    if (rest == 1) {
      final chunk = bytes[i] << 16;
      sb.write(_b64url[(chunk >> 18) & 0x3F]);
      sb.write(_b64url[(chunk >> 12) & 0x3F]);
    } else if (rest == 2) {
      final chunk = (bytes[i] << 16) | (bytes[i + 1] << 8);
      sb.write(_b64url[(chunk >> 18) & 0x3F]);
      sb.write(_b64url[(chunk >> 12) & 0x3F]);
      sb.write(_b64url[(chunk >> 6) & 0x3F]);
    }
    return sb.toString();
  }
}
