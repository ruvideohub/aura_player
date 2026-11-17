import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../services/library.dart';
import '../../services/native_bridge.dart';
import '../../services/settings.dart';
import '../../state/player_controller.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  Timer? _clock;
  int _sleepMinutes = 0;
  bool _checkingPerms = false;
  String _permStatus = '';

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(playerProvider).sleepActive) setState(() {});
    });
    _refreshPermissionStatus();
  }

  Future<void> _refreshPermissionStatus() async {
    if (!Platform.isAndroid) return;
    try {
      final audio = await Permission.audio.status;
      final video = await Permission.videos.status;
      final storage = await Permission.storage.status;
      setState(() {
        _permStatus = 'Аудио: ${audio.isGranted ? "✓" : "✗"} • Видео: ${video.isGranted ? "✓" : "✗"} • Хранилище: ${storage.isGranted ? "✓" : "—"}';
      });
    } catch (_) {
      setState(() => _permStatus = '');
    }
  }

  Future<bool> _requestPermissions() async {
    setState(() => _checkingPerms = true);
    try {
      final perms = <Permission>[Permission.storage];
      try {
        perms.addAll([Permission.audio, Permission.videos, Permission.photos]);
      } catch (_) {}
      final results = await perms.request();
      await _refreshPermissionStatus();
      final granted = results.values.any((s) => s.isGranted || s.isLimited);
      if (!granted) {
        final denied = results.values.any((s) => s.isPermanentlyDenied);
        if (denied && mounted) _showPermDialog();
      }
      return granted;
    } finally {
      setState(() => _checkingPerms = false);
    }
  }

  void _showPermDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Разрешения не даны'),
      content: const Text('Без разрешений AURA не видит файлы. Открой настройки и включи доступ к музыке и видео.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        FilledButton(onPressed: () { Navigator.pop(ctx); openAppSettings(); }, child: const Text('Открыть настройки')),
      ],
    ));
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() { _clock?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final lib = ref.watch(libraryProvider);
    final player = ref.watch(playerProvider);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // Разрешения — компактно
            if (Platform.isAndroid)
              _card(theme, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _sectionTitle(theme, Icons.security_rounded, 'Разрешения', 'Доступ к файлам для сканирования'),
                const SizedBox(height: 12),
                _permRow(theme, accent),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 8, children: [
                  FilledButton.icon(
                    onPressed: _checkingPerms ? null : () async {
                      final ok = await _requestPermissions();
                      if (ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Разрешения получены')));
                    },
                    icon: _checkingPerms ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.verified_user_rounded, size: 18),
                    label: const Text('Запросить доступ'),
                  ),
                  OutlinedButton.icon(onPressed: () => openAppSettings(), icon: const Icon(Icons.settings_rounded, size: 18), label: const Text('Системные настройки')),
                ]),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: _checkingPerms ? null : () async {
                    final m = ScaffoldMessenger.of(context);
                    final ok = await _requestPermissions();
                    if (!ok) { m.showSnackBar(const SnackBar(content: Text('Сначала дай разрешения'))); return; }
                    await ref.read(libraryProvider).scan();
                    final l = ref.read(libraryProvider);
                    m.showSnackBar(SnackBar(content: Text(l.lastScanError != null ? 'Ошибка: ${l.lastScanError}' : 'Добавлено ${l.lastScanAdded} файлов')));
                  },
                  icon: lib.scanning ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(lib.scanning ? 'Сканирую...' : 'Сканировать сейчас (${lib.audio.length + lib.video.length})'),
                ),
              ])),
            if (Platform.isAndroid) const SizedBox(height: 14),

            // Внешний вид
            _card(theme, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle(theme, Icons.palette_rounded, 'Внешний вид', 'Тема и акцентный цвет'),
              const SizedBox(height: 12),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('Авто'), icon: Icon(Icons.brightness_auto_rounded, size: 16)),
                  ButtonSegment(value: ThemeMode.light, label: Text('Светлая'), icon: Icon(Icons.light_mode_rounded, size: 16)),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Тёмная'), icon: Icon(Icons.dark_mode_rounded, size: 16)),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (s) => settings.setThemeMode(s.first),
              ),
              const SizedBox(height: 14),
              Text('Акцент', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6))),
              const SizedBox(height: 8),
              Wrap(spacing: 10, children: [
                for (var i = 0; i < accents.length; i++)
                  Tooltip(
                    message: accents[i].label,
                    child: InkWell(
                      onTap: () => settings.setAccent(i),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: accents[i].color,
                          shape: BoxShape.circle,
                          border: Border.all(color: settings.accentIndex == i ? theme.colorScheme.onSurface : Colors.transparent, width: 2),
                          boxShadow: [BoxShadow(color: accents[i].color.withOpacity(0.35), blurRadius: 8)],
                        ),
                        child: settings.accentIndex == i ? const Icon(Icons.check_rounded, size: 16, color: Colors.black) : null,
                      ),
                    ),
                  ),
              ]),
            ])),
            const SizedBox(height: 14),

            // Визуализатор
            _card(theme, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle(theme, Icons.graphic_eq_rounded, 'Визуализатор', 'Столбики, волна, сфера'),
              const SizedBox(height: 12),
              SegmentedButton<VisualizerMode>(
                segments: const [
                  ButtonSegment(value: VisualizerMode.bars, label: Text('Столбики')),
                  ButtonSegment(value: VisualizerMode.wave, label: Text('Волна')),
                  ButtonSegment(value: VisualizerMode.orb, label: Text('Сфера')),
                ],
                selected: {settings.visualizerMode},
                onSelectionChanged: (s) => settings.setVisualizerMode(s.first),
              ),
              const SizedBox(height: 12),
              Row(children: [
                SizedBox(width: 120, child: Text('Прозрачность', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.7)))),
                Expanded(child: Slider(min: 0.15, max: 1, value: settings.visualizerOpacity, onChanged: settings.setVisualizerOpacity, activeColor: accent)),
                Text('${(settings.visualizerOpacity*100).round()}%', style: const TextStyle(fontSize: 12)),
              ]),
              SwitchListTile(
                contentPadding: EdgeInsets.zero, dense: true,
                title: const Text('Мини-визуализатор', style: TextStyle(fontSize: 14)),
                subtitle: const Text('У плеера снизу', style: TextStyle(fontSize: 12)),
                value: settings.miniViz,
                onChanged: settings.setMiniViz,
                activeColor: accent,
              ),
            ])),
            const SizedBox(height: 14),

            // Воспроизведение
            _card(theme, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle(theme, Icons.play_circle_rounded, 'Воспроизведение', 'Позиция, таймер сна'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero, dense: true,
                title: const Text('Продолжать с места остановки'),
                subtitle: Text('Запоминает позицию каждого файла', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6))),
                value: settings.restorePositions,
                onChanged: settings.setRestorePositions,
                activeColor: accent,
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero, dense: true,
                title: const Text('Таймер сна', style: TextStyle(fontSize: 14)),
                subtitle: player.sleepActive && player.sleepEndsAt != null
                    ? Text('Выключится в ${player.sleepEndsAt!.hour.toString().padLeft(2,'0')}:${player.sleepEndsAt!.minute.toString().padLeft(2,'0')}', style: TextStyle(fontSize: 12, color: accent))
                    : const Text('Отключен', style: TextStyle(fontSize: 12)),
                trailing: DropdownButton<int>(
                  value: _sleepMinutes,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(12),
                  items: const [DropdownMenuItem(value: 0, child: Text('Выкл')), DropdownMenuItem(value: 15, child: Text('15м')), DropdownMenuItem(value: 30, child: Text('30м')), DropdownMenuItem(value: 60, child: Text('60м')), DropdownMenuItem(value: 90, child: Text('90м'))],
                  onChanged: (v) { setState(() => _sleepMinutes = v ?? 0); player.setSleepTimer(v==null||v==0?null:Duration(minutes: v)); },
                ),
              ),
              Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () { ref.read(libraryProvider).clearPositions(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Позиции сброшены'))); }, child: const Text('Сбросить позиции'))),
            ])),
            const SizedBox(height: 14),

            // Библиотека
            _card(theme, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle(theme, Icons.folder_rounded, 'Библиотека', Platform.isAndroid ? 'MediaStore • сканирование' : 'Папки сканирования'),
              const SizedBox(height: 10),
              if (NativeBridge.isAndroid) ...[
                Text('На Android берём из MediaStore. Дай разрешения и нажми Сканировать.', style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurface.withOpacity(0.6))),
                const SizedBox(height: 10),
                Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  FilledButton.icon(
                    onPressed: lib.scanning ? null : () async {
                      final m = ScaffoldMessenger.of(context);
                      final ok = await _requestPermissions();
                      if (!ok) { m.showSnackBar(const SnackBar(content: Text('Нужны разрешения'))); return; }
                      await ref.read(libraryProvider).scan();
                      final l = ref.read(libraryProvider);
                      m.showSnackBar(SnackBar(content: Text(l.lastScanError != null ? 'Ошибка: ${l.lastScanError}' : 'Добавлено ${l.lastScanAdded}')));
                    },
                    icon: lib.scanning ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(lib.scanning ? 'Сканирую...' : 'Сканировать'),
                  ),
                  Chip(label: Text('${lib.audio.length} аудио • ${lib.video.length} видео', style: const TextStyle(fontSize: 12)), visualDensity: VisualDensity.compact),
                ]),
              ] else ...[
                if (settings.scanDirs.isEmpty) Text('Папки не заданы.', style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurface.withOpacity(0.55)))
                else ...settings.scanDirs.map((dir) => ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.folder_rounded, size: 20), title: Text(dir, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)), trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18), onPressed: () => settings.removeScanDir(dir)))),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  OutlinedButton.icon(onPressed: () async { final dir = await getDirectoryPath(); if (dir != null) settings.addScanDir(dir); }, icon: const Icon(Icons.create_new_folder_rounded, size: 18), label: const Text('Добавить')),
                  FilledButton.icon(onPressed: lib.scanning ? null : () async { await ref.read(libraryProvider).scan(); final l = ref.read(libraryProvider); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.lastScanError != null ? 'Ошибка: ${l.lastScanError}' : 'Добавлено ${l.lastScanAdded}'))); }, icon: lib.scanning ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.manage_search_rounded, size: 18), label: const Text('Сканировать')),
                ]),
              ],
            ])),
            const SizedBox(height: 14),

            // О приложении — новый дизайн с автором
            _card(theme, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle(theme, Icons.info_rounded, 'О приложении', 'AURA Player 2.0'),
              const SizedBox(height: 14),
              Row(children: [
                Container(width: 56, height: 56, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.graphic_eq_rounded, size: 28, color: Colors.black)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('AURA Player', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  Text('Версия 2.0.0+23 • Flutter + Kotlin', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6))),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.person_rounded, size: 14, color: accent),
                    const SizedBox(width: 4),
                    Text('Автор: bytebudda', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accent)),
                  ]),
                ])),
              ]),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: accent.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.dividerColor)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.code_rounded, size: 16, color: accent),
                    const SizedBox(width: 6),
                    Text('Открытый исходный код', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: accent)),
                  ]),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _openUrl('https://github.com/ByteBudda/aura_player'),
                    child: Row(children: [
                      const Icon(Icons.link_rounded, size: 16),
                      const SizedBox(width: 6),
                      const Expanded(child: Text('github.com/ByteBudda/aura_player', style: TextStyle(fontSize: 13, decoration: TextDecoration.underline))),
                      Icon(Icons.open_in_new_rounded, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _openUrl('https://github.com/ByteBudda'),
                    child: Row(children: [
                      const Icon(Icons.alternate_email_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('@bytebudda_soft', style: TextStyle(fontSize: 13, color: accent, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                OutlinedButton.icon(onPressed: () => _openUrl('https://github.com/ByteBudda/aura_player'), icon: const Icon(Icons.star_rounded, size: 18), label: const Text('Поставить ⭐ на GitHub')),
                FilledButton.icon(onPressed: () => _openUrl('https://github.com/ByteBudda/aura_player/issues'), icon: const Icon(Icons.bug_report_rounded, size: 18), label: const Text('Сообщить об ошибке')),
              ]),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Text('Движок', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: theme.colorScheme.onSurface.withOpacity(0.5))),
              const SizedBox(height: 6),
              _aboutRow(Icons.movie_rounded, 'Видео', 'ExoPlayer (Android) • libmpv (Desktop) — HLS/DASH/fMP4, MKV, HEVC, субтитры'),
              _aboutRow(Icons.music_note_rounded, 'Аудио', 'AudioFX + BassBoost • FLAC, MP3, OGG, M4A, Opus'),
              _aboutRow(Icons.equalizer_rounded, 'Эффекты', '10-полосный EQ • пресеты Rock/Pop/Jazz • визуализатор'),
              const SizedBox(height: 8),
              _aboutRow(Icons.keyboard_rounded, 'Горячие клавиши', 'Space, ←/→, M, F, N/P, L, S, [ ]'),
            ])),
            const SizedBox(height: 8),
            Center(child: Text('Сделано с ♥ для меломанов • 2025 bytebudda', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.4)))),
            const SizedBox(height: 8),
            ])),
        ),
      ],
    );
  }

  Widget _permRow(ThemeData theme, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.dividerColor)),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(_permStatus.isEmpty ? 'Проверка...' : _permStatus, style: const TextStyle(fontSize: 12))),
        Icon(Icons.check_circle_rounded, size: 16, color: _permStatus.contains('granted') ? Colors.green : Colors.grey),
      ]),
    );
  }

  Widget _aboutRow(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        SizedBox(width: 90, child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        Expanded(child: Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
      ]),
    );
  }

  Widget _card(ThemeData theme, {required Widget child}) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: child));
  }

  Widget _sectionTitle(ThemeData theme, IconData icon, String title, String subtitle) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: theme.colorScheme.primary)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text(subtitle, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.5))),
      ])),
    ]);
  }
}
