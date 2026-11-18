import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Порт VkAuthCore.kt — чистое ядро PKCE, без Android-зависимостей.
class VkAuthSession {
  final String accessToken;
  final String refreshToken;
  final int expiresAtMs;
  final int userId;
  final String deviceId;
  const VkAuthSession({required this.accessToken, required this.refreshToken, required this.expiresAtMs, required this.userId, required this.deviceId});
  bool isActive([int? nowMs]) => accessToken.isNotEmpty && (nowMs ?? DateTime.now().millisecondsSinceEpoch) < expiresAtMs;
}

class VkAuthCore {
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
  static const _verifierLen = 128;
  static const _b64url = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

  static String generateCodeVerifier([Random? r]) {
    final rnd = r ?? Random.secure();
    return List.generate(_verifierLen, (_) => _alphabet[rnd.nextInt(_alphabet.length)]).join();
  }

  static String generateCodeChallenge(String verifier) {
    final hash = sha256.convert(ascii.encode(verifier)).bytes;
    return base64UrlNoPad(hash);
  }

  static String generateState([Random? r]) {
    final rnd = r ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64UrlNoPad(bytes);
  }

  static String generateDeviceId([Random? r]) {
    final rnd = r ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Разбор redirect: blank.html?code=..&state=..&device_id=..
  static ({String code, String state, String? deviceId})? parseRedirect(String url) {
    if (!url.contains('blank.html') && !url.contains('oauth.vk.')) return null;
    final q = url.contains('?') ? url.split('?').last : '';
    if (q.isEmpty) return null;
    String? code, state, deviceId;
    for (final pair in q.split('&')) {
      final idx = pair.indexOf('=');
      if (idx <= 0) continue;
      final k = pair.substring(0, idx);
      final v = Uri.decodeComponent(pair.substring(idx + 1));
      if (k == 'code') code = v;
      if (k == 'state') state = v;
      if (k == 'device_id') deviceId = v;
    }
    if (code == null) return null;
    return (code: code, state: state ?? '', deviceId: deviceId);
  }

  static bool validateState(String expected, String received) => expected.isNotEmpty && received == expected;

  static String base64UrlNoPad(List<int> bytes) {
    final sb = StringBuffer();
    int i = 0;
    while (i + 2 < bytes.length) {
      final chunk = ((bytes[i] & 0xFF) << 16) | ((bytes[i + 1] & 0xFF) << 8) | (bytes[i + 2] & 0xFF);
      sb.write(_b64url[(chunk >> 18) & 0x3F]);
      sb.write(_b64url[(chunk >> 12) & 0x3F]);
      sb.write(_b64url[(chunk >> 6) & 0x3F]);
      sb.write(_b64url[chunk & 0x3F]);
      i += 3;
    }
    final rest = bytes.length - i;
    if (rest == 1) {
      final chunk = (bytes[i] & 0xFF) << 16;
      sb.write(_b64url[(chunk >> 18) & 0x3F]);
      sb.write(_b64url[(chunk >> 12) & 0x3F]);
    } else if (rest == 2) {
      final chunk = ((bytes[i] & 0xFF) << 16) | ((bytes[i + 1] & 0xFF) << 8);
      sb.write(_b64url[(chunk >> 18) & 0x3F]);
      sb.write(_b64url[(chunk >> 12) & 0x3F]);
      sb.write(_b64url[(chunk >> 6) & 0x3F]);
    }
    return sb.toString();
  }
}
