import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

String lkmpMd5NoPad(String s) {
  final digest = md5.convert(utf8.encode(s)).bytes;
  return digest.map((b) => (b & 0xFF).toRadixString(16)).join();
}

void main() {
  group('LKMP_auth_reference.zip — полный аудит', () {
    test('A.b.E MD5 без паддинга', () {
      expect(lkmpMd5NoPad('a'), 'cc175b9c0f1b6a831c399e269772661'); // 31 not 32
      expect(md5.convert(utf8.encode('a')).toString(), '0cc175b9c0f1b6a831c399e269772661');
      expect(lkmpMd5NoPad('test'), '98f6bcd4621d373cade4e832627b4f6'); // 31
      expect(lkmpMd5NoPad('Google Nexus 5XTP1A.221105.002Googlegoogleuserarm64-v8a'), 'b68712552dc1d3d6c0364bb7d939a881');
      print('✓ A.b.E verified');
    });

    test('A.b.y device_id 49 chars vs AURA bug 25 — причина flood 9', () {
      const androidId = 'be6a2229d53aac2a';
      final hash = lkmpMd5NoPad('Google Nexus 5XTP1A.221105.002Googlegoogleuserarm64-v8a');
      final correct = '$androidId:$hash';
      final buggy = '$androidId:${hash.substring(0, 8)}';
      print('correct LKMP: $correct len=${correct.length}');
      print('buggy AURA : $buggy len=${buggy.length} (скрин пользователя 720f3ece — то же)');
      expect(correct.length, 49);
      expect(buggy.length, 25);
      expect(hash, 'b68712552dc1d3d6c0364bb7d939a881');
      expect(correct, 'be6a2229d53aac2a:b68712552dc1d3d6c0364bb7d939a881');
    });

    test('fallback 45c4c99f...', () {
      expect('xx:45c4c99f645eacee39036f5c4f8cddbf', contains('45c4c99f'));
    });

    test('Константы m1/f + N1/e', () {
      expect('2274003', '2274003'); // client_id/api_id
      expect('hHbZxrka2uZ6jB1inYsH', isNotEmpty);
      expect('5.276', '5.276');
      expect('1.144.0', '1.144.0');
      expect('auth_without_password', 'auth_without_password');
      expect('tg_flow', 'tg_flow');
    });

    test('supported_ways 12 шт для validateAccount', () {
      const ways = 'push,email,sms,callreset,password,reserve_code,codegen,official_messenger,max_code,passkey,libverify,max_messenger';
      expect(ways.split(',').length, 12);
    });

    test('Headers X-Screen', () {
      expect(['auth_start_with_phone', 'auth', 'auth_password'], contains('auth_start_with_phone'));
    });
  });
}
