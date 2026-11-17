import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(playerProvider).sleepActive) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final lib = ref.watch(libraryProvider);
    final player = ref.watch(playerProvider);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- Внешний вид ----
              _card(
                theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(theme, Icons.palette_outlined, 'Внешний вид'),
                    const SizedBox(height: 12),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('Системная'),
                          icon: Icon(Icons.brightness_auto_outlined, size: 16),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Светлая'),
                          icon: Icon(Icons.light_mode_outlined, size: 16),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Тёмная'),
                          icon: Icon(Icons.dark_mode_outlined, size: 16),
                        ),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (s) =>
                          settings.setThemeMode(s.first),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      children: [
                        for (var i = 0; i < accents.length; i++)
                          Tooltip(
                            message: accents[i].label,
                            child: InkWell(
                              onTap: () => settings.setAccent(i),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: accents[i].color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: settings.accentIndex == i
                                        ? theme.colorScheme.onSurface
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          accents[i].color.withOpacity(0.4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: settings.accentIndex == i
                                    ? const Icon(Icons.check_rounded,
                                        size: 16, color: Colors.black)
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ---- Визуализатор ----
              _card(
                theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(theme, Icons.graphic_eq_rounded, 'Визуализатор'),
                    const SizedBox(height: 12),
                    SegmentedButton<VisualizerMode>(
                      segments: const [
                        ButtonSegment(
                          value: VisualizerMode.bars,
                          label: Text('Столбики'),
                        ),
                        ButtonSegment(
                          value: VisualizerMode.wave,
                          label: Text('Волна'),
                        ),
                        ButtonSegment(
                          value: VisualizerMode.orb,
                          label: Text('Сфера'),
                        ),
                      ],
                      selected: {settings.visualizerMode},
                      onSelectionChanged: (s) =>
                          settings.setVisualizerMode(s.first),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        SizedBox(
                          width: 150,
                          child: Text(
                            'Прозрачность',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.7),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            min: 0.15,
                            max: 1,
                            value: settings.visualizerOpacity,
                            onChanged: settings.setVisualizerOpacity,
                            activeColor: accent,
                          ),
                        ),
                        Text(
                          '${(settings.visualizerOpacity * 100).round()}%',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Мини-визуализатор у плеера снизу'),
                      value: settings.miniViz,
                      onChanged: settings.setMiniViz,
                      activeColor: accent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ---- Воспроизведение ----
              _card(
                theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(
                        theme, Icons.play_circle_outline_rounded, 'Воспроизведение'),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Продолжать с места остановки'),
                      subtitle: const Text(
                        'AURA запоминает позицию каждого файла',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: settings.restorePositions,
                      onChanged: settings.setRestorePositions,
                      activeColor: accent,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Таймер сна',
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<int>(
                          value: _sleepMinutes,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('Выключен')),
                            DropdownMenuItem(value: 15, child: Text('15 минут')),
                            DropdownMenuItem(value: 30, child: Text('30 минут')),
                            DropdownMenuItem(value: 60, child: Text('60 минут')),
                            DropdownMenuItem(value: 90, child: Text('90 минут')),
                          ],
                          onChanged: (v) {
                            setState(() => _sleepMinutes = v ?? 0);
                            player.setSleepTimer(
                              v == null || v == 0
                                  ? null
                                  : Duration(minutes: v),
                            );
                          },
                        ),
                        if (player.sleepActive && player.sleepEndsAt != null)
                          Expanded(
                            child: Text(
                              'выключится в '
                                  '${player.sleepEndsAt!.hour.toString().padLeft(2, '0')}:'
                                  '${player.sleepEndsAt!.minute.toString().padLeft(2, '0')}',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 12,
                                color: accent,
                              ),
                            ),
                          ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(libraryProvider).clearPositions();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Сохранённые позиции сброшены'),
                          ),
                        );
                      },
                      child: const Text('Сбросить сохранённые позиции'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ---- Библиотека ----
              _card(
                theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(theme, Icons.folder_outlined, 'Библиотека'),
                    const SizedBox(height: 8),
                    if (NativeBridge.isAndroid)
                      Text(
                        'На Android библиотека сканируется через MediaStore '
                        '— все музыка и видео на устройстве.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color:
                              theme.colorScheme.onSurface.withOpacity(0.55),
                        ),
                      )
                    else ...[
                      if (settings.scanDirs.isEmpty)
                        Text(
                          'Папки сканирования не заданы.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: theme.colorScheme.onSurface.withOpacity(0.55),
                          ),
                        )
                      else
                        ...settings.scanDirs.map(
                          (dir) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.folder_rounded, size: 20),
                            title: Text(
                              dir,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18),
                              onPressed: () => settings.removeScanDir(dir),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                final dir = await getDirectoryPath();
                                if (dir != null) settings.addScanDir(dir);
                              } catch (_) {}
                            },
                            icon: const Icon(Icons.create_new_folder_outlined,
                                size: 18),
                            label: const Text('Добавить папку'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: lib.scanning
                                ? null
                                : () async {
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    await ref.read(libraryProvider).scan();
                                    final l =
                                        ref.read(libraryProvider);
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          l.lastScanError != null
                                              ? 'Ошибка: ${l.lastScanError}'
                                              : 'Добавлено ${l.lastScanAdded} новых файлов',
                                        ),
                                      ),
                                    );
                                  },
                            icon: lib.scanning
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.manage_search_rounded,
                                    size: 18),
                            label: const Text('Сканировать'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ---- О приложении ----
              _card(
                theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(theme, Icons.info_outline_rounded, 'О приложении'),
                    const SizedBox(height: 10),
                    Text(
                      'AURA Player 2.0 — Flutter + Kotlin',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Интерфейс: Flutter Material 3 · Состояние: Riverpod\n'
                      'Движок: libmpv через media_kit (все форматы, субтитры, EQ)\n'
                      'Android: Kotlin — MediaStore, обложки, audiofx-эквалайзер\n'
                      'Горячие клавиши: Space, стрелки, M, F, N, P, L, S, [ и ]',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.65),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card(ThemeData theme, {required Widget child}) {
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: child));
  }

  Widget _sectionTitle(ThemeData theme, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Text(
          text,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
