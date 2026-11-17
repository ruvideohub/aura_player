import 'dart:io';

import '../models/models.dart';

/// Хелпер для ассоциаций видео-файлов на Windows.
/// Пишет в HKCU\Software\Classes — не требует админа.
class WindowsAssociations {
  static const progId = 'AURAPlayer.Video';
  static const progDesc = 'AURA Player Video File';

  static bool get isWindows => Platform.isWindows;

  static String get exePath => Platform.resolvedExecutable;

  /// Проверка — ассоциирован ли .mp4 с нами
  static Future<bool> isAssociated() async {
    if (!isWindows) return false;
    try {
      final r = await Process.run('reg', [
        'query',
        r'HKCU\Software\Classes\.mp4',
        '/ve',
      ], runInShell: true);
      final out = (r.stdout.toString() + r.stderr.toString()).toLowerCase();
      return out.contains(progId.toLowerCase());
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, bool>> statusByExt() async {
    final map = <String, bool>{};
    if (!isWindows) return map;
    for (final ext in videoExtensions) {
      try {
        final r = await Process.run('reg', [
          'query',
          'HKCU\\Software\\Classes\\.$ext',
          '/ve',
        ], runInShell: true);
        final out = (r.stdout.toString() + r.stderr.toString()).toLowerCase();
        map[ext] = out.contains(progId.toLowerCase());
      } catch (_) {
        map[ext] = false;
      }
    }
    return map;
  }

  static Future<bool> register() async {
    if (!isWindows) return false;
    final exe = exePath;
    // Экранируем для reg
    final cmd = '"$exe" "%1"';
    final icon = '"$exe",0';
    try {
      // ProgId
      await _regAdd(r'HKCU\Software\Classes\' + progId, null, progDesc);
      await _regAdd(r'HKCU\Software\Classes\' + progId + r'\DefaultIcon', null, icon);
      await _regAdd(r'HKCU\Software\Classes\' + progId + r'\shell\open\command', null, cmd);
      // Friendly + NoOpenWith? не нужно
      // Для каждого видео-расширения
      for (final ext in videoExtensions) {
        await _regAdd('HKCU\\Software\\Classes\\.$ext', null, progId);
        // Добавляем в OpenWithProgids чтобы проводник показывал
        await _regAdd('HKCU\\Software\\Classes\\.$ext\\OpenWithProgids', progId, '');
      }
      // Сообщаем оболочке об изменении (SHChangeNotify) — через powershell если доступно
      try {
        await Process.run('powershell', [
          '-Command',
          r'Add-Type -MemberDefinition "[DllImport(""shell32.dll"")] public static extern void SHChangeNotify(int w,float u,int f,int d);" -Name ShellUtil -Namespace PInvoke; [PInvoke.ShellUtil]::SHChangeNotify(0x08000000,0,0,0)'
        ], runInShell: true);
      } catch (_) {}
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> unregister() async {
    if (!isWindows) return false;
    try {
      for (final ext in videoExtensions) {
        // Удаляем только если оно указывает на нас
        try {
          final r = await Process.run('reg', [
            'query',
            'HKCU\\Software\\Classes\\.$ext',
            '/ve',
          ], runInShell: true);
          final out = (r.stdout.toString() + r.stderr.toString()).toLowerCase();
          if (out.contains(progId.toLowerCase())) {
            await Process.run('reg', [
              'delete',
              'HKCU\\Software\\Classes\\.$ext',
              '/f',
            ], runInShell: true);
            // Также чистим OpenWithProgids
            await Process.run('reg', [
              'delete',
              'HKCU\\Software\\Classes\\.$ext\\OpenWithProgids',
              '/v',
              progId,
              '/f',
            ], runInShell: true);
          }
        } catch (_) {}
      }
      await Process.run('reg', [
        'delete',
        'HKCU\\Software\\Classes\\$progId',
        '/f',
      ], runInShell: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _regAdd(String key, String? valueName, String data) async {
    final args = ['add', key];
    if (valueName == null) {
      args.addAll(['/ve', '/d', data, '/f']);
    } else if (data.isEmpty) {
      args.addAll(['/v', valueName, '/d', '', '/f']);
    } else {
      args.addAll(['/v', valueName, '/d', data, '/f']);
    }
    final r = await Process.run('reg', args, runInShell: true);
    if (r.exitCode != 0) {
      // Попробуем с кавычками
      // throw to let caller know
      // но не критично
    }
  }
}
