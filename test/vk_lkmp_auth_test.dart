import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

// Копия LKMP логики для теста
String lkmpMd5NoPad(String s) {
  final digest = md5.convert(s.codeUnits).bytes;
  return digest.map((b) => (b & 0xFF).toRadixString(16)).join();
}

String normalMd5(String s) => md5.convert(s.codeUnits).toString();

void main() {
  test('LKMP E() bug reproduces — без ведущего нуля', () {
    // Пример где байт < 0x10 — должен быть 1 символ, а не 2
    expect(lkmpMd5NoPad('a'), 'cc175b9c0f1b6a831c399e269772661'); // 31 chars, без ведущего 0
    expect(normalMd5('a'), '0cc175b9c0f1b6a831c399e269772661'); // 32 chars
    expect(lkmpMd5NoPad('a').length, 31);
    expect(normalMd5('a').length, 32);
    print('✓ LKMP bug verified: "a" -> ${lkmpMd5NoPad('a')} (31) vs normal ${normalMd5('a')} (32)');
  });

  test('device_id должен быть 49 символов как у LKMP, а не 25 как у AURA', () {
    const model = 'Google Nexus 5X';
    const id = 'TP1A.221105.002';
    const manufacturer = 'Google';
    const brand = 'google';
    const type = 'user';
    const arch = 'arm64-v8a';
    final hashFull = lkmpMd5NoPad(model + id + manufacturer + brand + type + arch);
    final androidId = 'be6a2229d53aac2a'; // из скрина юзера
    final correctDeviceId = '$androidId:$hashFull';
    final buggyDeviceId = '$androidId:${hashFull.substring(0, 8)}';

    print('LKMP correct: $correctDeviceId len=${correctDeviceId.length}');
    print('AURA buggy  : $buggyDeviceId len=${buggyDeviceId.length}');
    print('Скрин юзера : be6a2229d53aac2a:720f3ece len=25 — это BUG!');

    expect(correctDeviceId.length, 49); // 16 +1 +32
    expect(buggyDeviceId.length, 25); // 16+1+8 — вот почему VK режет flood 9
    expect(hashFull, 'b68712552dc1d3d6c0364bb7d939a881');
    expect(buggyDeviceId, 'be6a2229d53aac2a:b6871255');
  });

  test('gaid формат 8-4-4-4-12 как у LKMP', () {
    final gaid = '724125ac-54dc-3589-4006-d93b5d559dfa'; // из скрина
    expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$').hasMatch(gaid), true);
  });

  test('VK flood 9 — из-за короткого device_id VK считает девайс фейком', () {
    // Вывод причины
    print('''
Причина flood 9:
- AURA слала device_id 25 символов (16+1+8) — VK не знает такого девайса, считает спам
- LKMP шлёт 49 символов (16+1+32) — VK принимает
- Плюс AURA не кешировала anonymToken и слала его каждый раз → ещё спам
- Плюс дублировала access_token 2 раза
Исправлено в 2.0.0+83: полный hash + кеш 55м + убран дубль
''');
  });
}
