import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../services/library.dart';
import '../../services/settings.dart';
import '../../state/player_controller.dart';
import '../state/ui_state.dart';
import '../widgets/cover_art.dart';
import '../widgets/seekbar.dart';
import '../widgets/visualizer.dart';
import 'vk_music/vk_music_page.dart';

class AudioPage extends ConsumerStatefulWidget {
  const AudioPage({super.key});

  @override
  ConsumerState<AudioPage> createState() => _AudioPageState();
}

enum _AudioSource { offline, vk }

class _AudioPageState extends ConsumerState<AudioPage> {
  String _query = '';
  String _sort = 'title';
  bool _showLibrary = false;
  _AudioSource _source = _AudioSource.offline;

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(playerProvider.select((p) => p.current));
    final hasVideo = ref.watch(playerProvider.select((p) => p.hasVideo));
    final player = ref.read(playerProvider);
    final settings = ref.watch(settingsProvider);
    final lib = ref.watch(libraryProvider);
    final theme = Theme.of(context);

    if (current != null && !hasVideo) {
      if (_showLibrary) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.dividerColor))),
              child: Row(
                children: [
                  CoverArt(track: player.current!, size: 36, radius: 8),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(player.current!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), Text(player.isPlaying ? 'Играет' : 'Пауза', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.5)))])),
                  IconButton(icon: Icon(player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded), onPressed: player.togglePlay),
                  FilledButton.icon(onPressed: () => setState(() => _showLibrary = false), icon: const Icon(Icons.graphic_eq_rounded, size: 16), label: const Text('Плеер')),
                ],
              ),
            ),
            Expanded(child: _audioLibrary(context, lib, player, theme)),
          ],
        );
      }
      final nowPlaying = _NowPlaying(player: player, settings: settings, onShowLibrary: () => setState(() => _showLibrary = true));
      final side = _SidePanel(player: player);
      final wide = MediaQuery.of(context).size.width >= 1100;
      if (wide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 5, child: nowPlaying),
            VerticalDivider(width: 1, color: theme.dividerColor),
            Expanded(flex: 4, child: side),
          ],
        );
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [nowPlaying, const SizedBox(height: 16), SizedBox(height: 420, child: side)],
      );
    }
    if (_showLibrary && (current == null || hasVideo)) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _showLibrary = false); });
    }
    return _audioLibrary(context, lib, player, theme);
  }

  Widget _sourceToggle(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Center(
        child: SegmentedButton<_AudioSource>(
          segments: const [
            ButtonSegment(value: _AudioSource.offline, label: Text('Офлайн'), icon: Icon(Icons.folder_rounded, size: 16)),
            ButtonSegment(value: _AudioSource.vk, label: Text('VK Музыка'), icon: Icon(Icons.cloud_rounded, size: 16)),
          ],
          selected: {_source},
          onSelectionChanged: (s) => setState(() => _source = s.first),
          showSelectedIcon: false,
          style: ButtonStyle(visualDensity: VisualDensity.compact),
        ),
      ),
    );
  }

  Widget _audioLibrary(BuildContext context, LibraryController lib, PlayerController player, ThemeData theme) {
    if (_source == _AudioSource.vk) {
      return Column(
        children: [
          _sourceToggle(theme),
          const Divider(height: 1),
          const Expanded(child: VkMusicPage()),
        ],
      );
    }

    final accent = theme.colorScheme.primary;
    final list = _filtered(lib);

    if (lib.audio.isEmpty && list.isEmpty && _query.isEmpty) {
      return Column(
        children: [
          _sourceToggle(theme),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.music_note_rounded, size: 72, color: accent),
                    const SizedBox(height: 16),
                    Text('Нет музыки', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Сканирование ещё не выполнено.\nОткрой файлы или запусти скан в Настройках.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                    ),
                    const SizedBox(height: 20),
                    Wrap(spacing: 12, alignment: WrapAlignment.center, children: [
                      FilledButton.icon(
                        onPressed: _openFiles,
                        icon: const Icon(Icons.folder_open_rounded),
                        label: const Text('Открыть файлы'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          if (lib.scanning) return;
                          final messenger = ScaffoldMessenger.of(context);
                          await lib.scan();
                          messenger.showSnackBar(SnackBar(
                            content: Text(lib.lastScanError != null ? 'Ошибка: ${lib.lastScanError}' : 'Добавлено ${lib.lastScanAdded} файлов'),
                          ));
                        },
                        icon: lib.scanning
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh_rounded),
                        label: Text(lib.scanning ? 'Сканирую...' : 'Сканировать'),
                      ),
                      TextButton(
                        onPressed: () => ref.read(pageProvider.notifier).state = 4,
                        child: const Text('Настройки'),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sourceToggle(theme),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(
                          hintText: 'Поиск по трекам, исполнителям…',
                          prefixIcon: Icon(Icons.search, size: 18),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _sort,
                      underline: const SizedBox.shrink(),
                      borderRadius: BorderRadius.circular(12),
                      items: const [
                        DropdownMenuItem(value: 'title', child: Text('По названию')),
                        DropdownMenuItem(value: 'artist', child: Text('По исполнителю')),
                        DropdownMenuItem(value: 'date', child: Text('По дате')),
                        DropdownMenuItem(value: 'duration', child: Text('По длительности')),
                      ],
                      onChanged: (v) => setState(() => _sort = v ?? 'title'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Открыть файлы',
                      onPressed: _openFiles,
                      icon: const Icon(Icons.add_rounded),
                    ),
                    IconButton(
                      tooltip: 'Сканировать',
                      onPressed: lib.scanning
                          ? null
                          : () async {
                              final m = ScaffoldMessenger.of(context);
                              await lib.scan();
                              m.showSnackBar(SnackBar(content: Text(lib.lastScanError != null ? 'Ошибка: ${lib.lastScanError}' : 'Добавлено ${lib.lastScanAdded}')));
                            },
                      icon: lib.scanning
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '${list.length} ${_plural(list.length)} · ${fmtSize(list.fold<int>(0, (s, t) => s + t.sizeBytes))}',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.55)),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: list.isEmpty
                      ? Center(
                          child: Text('Ничего не найдено', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5))),
                        )
                      : ListView.builder(
                          cacheExtent: 800,
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: true,
                          itemCount: list.length,
                          itemBuilder: (context, i) {
                            final t = list[i];
                            final isCurrent = ref.watch(playerProvider.select((p) => p.current?.path)) == t.path;
                            return RepaintBoundary(
                              child: ListTile(
                                leading: CoverArt(track: t, size: 48, radius: 10),
                                title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: isCurrent ? TextStyle(color: accent, fontWeight: FontWeight.w600) : null),
                                subtitle: Text([if (t.artist.isNotEmpty) t.artist, if (t.album.isNotEmpty) t.album].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(fmtTime(Duration(milliseconds: t.durationMs)), style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.5))),
                                  PopupMenuButton<String>(
                                    onSelected: (v) async {
                                      if (v == 'play') await ref.read(playerProvider).open(list, i);
                                      if (v == 'queue') {
                                        ref.read(playerProvider).enqueue([t]);
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Добавлено в очередь')));
                                      }
                                      if (v == 'playlist') _addToPlaylistDialog(t);
                                      if (v == 'remove') lib.removeTrack(t);
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'play', child: Text('Воспроизвести')),
                                      PopupMenuItem(value: 'queue', child: Text('В очередь')),
                                      PopupMenuItem(value: 'playlist', child: Text('В плейлист')),
                                      PopupMenuItem(value: 'remove', child: Text('Удалить')),
                                    ],
                                  ),
                                ]),
                                onTap: () => ref.read(playerProvider).open(list, i),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _plural(int n) {
    final m10 = n % 10;
    final m100 = n % 100;
    if (m10 == 1 && m100 != 11) return 'трек';
    if (m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 > 20)) return 'трека';
    return 'треков';
  }

  List<MediaTrack> _filtered(LibraryController lib) {
    final q = _query.trim().toLowerCase();
    var list = lib.audio;
    if (q.isNotEmpty) {
      list = list.where((t) => t.title.toLowerCase().contains(q) || t.artist.toLowerCase().contains(q) || t.album.toLowerCase().contains(q)).toList();
    }
    final sorted = List.of(list);
    switch (_sort) {
      case 'title':
        sorted.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'artist':
        sorted.sort((a, b) => (a.artist.isEmpty ? 'яяя' : a.artist.toLowerCase()).compareTo(b.artist.isEmpty ? 'яяя' : b.artist.toLowerCase()));
        break;
      case 'date':
        sorted.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
      case 'duration':
        sorted.sort((a, b) => b.durationMs.compareTo(a.durationMs));
        break;
    }
    return sorted;
  }

  Future<void> _openFiles() async {
    const typeGroup = XTypeGroup(label: 'Аудио', extensions: audioExtensions);
    try {
      final files = await openFiles(acceptedTypeGroups: [typeGroup]);
      if (files.isEmpty) return;
      final tracks = files.map((f) => MediaTrack.fromFile(File(f.path), isVideo: false)).toList();
      ref.read(libraryProvider).importTracks(tracks);
      await ref.read(playerProvider).open(tracks, 0);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _addToPlaylistDialog(MediaTrack t) async {
    final lib = ref.read(libraryProvider);
    if (lib.playlists.isEmpty) {
      final created = await _newPlaylistDialog();
      if (created != null) lib.addToPlaylist(created, t);
      return;
    }
    final id = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(14), child: Text('Выбрать плейлист', style: Theme.of(ctx).textTheme.titleMedium)),
          ...lib.playlists.map((p) => ListTile(leading: const Icon(Icons.queue_music_rounded), title: Text(p.name), subtitle: Text('${p.paths.length} треков'), onTap: () => Navigator.pop(ctx, p.id))),
          ListTile(leading: Icon(Icons.add, color: Theme.of(ctx).colorScheme.primary), title: const Text('Новый плейлист'), onTap: () => Navigator.pop(ctx, '__new__')),
        ]),
      ),
    );
    if (id == '__new__') {
      final created = await _newPlaylistDialog();
      if (created != null) lib.addToPlaylist(created, t);
    } else if (id != null) {
      lib.addToPlaylist(id, t);
    }
  }

  Future<String?> _newPlaylistDialog() async {
    final c = TextEditingController();
    final name = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(title: const Text('Новый плейлист'), content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Название')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')), FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Создать'))]));
    if (name == null || name.isEmpty) return null;
    final lib = ref.read(libraryProvider);
    lib.createPlaylist(name);
    return lib.playlists.last.id;
  }
}

class _NowPlaying extends StatelessWidget {
  final PlayerController player;
  final SettingsController settings;
  final VoidCallback? onShowLibrary;
  const _NowPlaying({required this.player, required this.settings, this.onShowLibrary});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final t = player.current!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: ClipRRect(borderRadius: BorderRadius.circular(24), child: CoverArt(track: t, size: 280, radius: 24))),
              const SizedBox(height: 20),
              if (onShowLibrary != null)
                Center(
                  child: OutlinedButton.icon(
                    onPressed: onShowLibrary,
                    icon: const Icon(Icons.list_rounded, size: 16),
                    label: const Text('К списку треков'),
                  ),
                ),
              Text(t.title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(t.artist.isEmpty ? 'Неизвестный исполнитель' : t.artist, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.65))),
              if (t.album.isNotEmpty) Text(t.album, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.45))),
              const SizedBox(height: 18),
              RepaintBoundary(child: SizedBox(height: 90, child: Visualizer(playing: player.isPlaying, mode: settings.visualizerMode, color: accent, opacity: settings.visualizerOpacity))),
              const SizedBox(height: 14),
              LiveSeekBar(),
              const SizedBox(height: 6),
              const _AudioMainControls(),
              const SizedBox(height: 8),
              const _AudioRateVolumeRow(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  final PlayerController player;
  const _SidePanel({required this.player});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(length: 2, child: Column(children: [TabBar(indicatorColor: theme.colorScheme.primary, labelColor: theme.colorScheme.onSurface, unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.5), tabs: const [Tab(text: 'Текст песни'), Tab(text: 'Очередь')]), Expanded(child: TabBarView(children: [_LyricsView(player: player), _QueueView(player: player)]))]));
  }
}

class _LyricsView extends ConsumerStatefulWidget {
  final PlayerController player;
  const _LyricsView({required this.player});
  @override
  ConsumerState<_LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<_LyricsView> {
  final ScrollController _scroll = ScrollController();
  int _lastIndex = -1;
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _maybeScroll(int index) {
    if (index == _lastIndex || !_scroll.hasClients) return;
    _lastIndex = index;
    if (index < 0) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }
    final target = (index * 40.0 - 80).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final lyrics = widget.player.lyrics;
    if (lyrics == null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.lyrics_outlined, size: 44, color: accent), const SizedBox(height: 12), Text('Текста нет', style: theme.textTheme.titleMedium), const SizedBox(height: 8), Text('Положи файл .lrc с тем же именем рядом\nс аудиофайлом — AURA покажет текст в такт.', textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.55)))])));
    return StreamBuilder<Duration>(
      stream: widget.player.positionStream,
      builder: (context, snap) {
        final index = lyrics.indexAt(snap.data ?? Duration.zero);
        _maybeScroll(index);
        return ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
          itemCount: lyrics.lines.length,
          itemBuilder: (context, i) {
            final active = i == index;
            return SizedBox(
              height: 40,
              child: Center(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: TextStyle(fontSize: active ? 17 : 14.5, fontWeight: active ? FontWeight.w700 : FontWeight.w400, color: active ? accent : theme.colorScheme.onSurface.withOpacity(0.5)),
                  child: Text(lyrics.lines[i].text, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _QueueView extends StatelessWidget {
  final PlayerController player;
  const _QueueView({required this.player});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
        child: Row(children: [
          Text('Очередь · ${player.queue.length}', style: theme.textTheme.titleMedium),
          const Spacer(),
          IconButton(tooltip: 'Перемешать (S)', onPressed: player.toggleShuffle, icon: Icon(Icons.shuffle_rounded, size: 18, color: player.shuffle ? accent : theme.colorScheme.onSurface.withOpacity(0.5))),
          IconButton(tooltip: 'Повтор (L)', onPressed: player.cycleRepeat, icon: Icon(Icons.repeat_rounded, size: 18, color: player.repeat == RepeatMode.off ? theme.colorScheme.onSurface.withOpacity(0.5) : accent)),
        ]),
      ),
      Expanded(
        child: ReorderableListView.builder(
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.only(bottom: 12),
          itemCount: player.queue.length,
          onReorder: player.reorderQueue,
          itemBuilder: (context, i) {
            final t = player.queue[i];
            final isCurrent = i == player.index;
            return ReorderableDragStartListener(
              key: ValueKey(t.path + i.toString()),
              index: i,
              child: ListTile(
                dense: true,
                leading: Text(isCurrent ? '▶' : '${i + 1}', style: TextStyle(color: isCurrent ? accent : null, fontWeight: FontWeight.bold)),
                title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: isCurrent ? TextStyle(color: accent, fontWeight: FontWeight.w600) : null),
                subtitle: Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                trailing: IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => player.removeFromQueue(i)),
                onTap: () => player.playAt(i),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _AudioMainControls extends ConsumerWidget {
  const _AudioMainControls();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shuffle = ref.watch(playerProvider.select((p) => p.shuffle));
    final repeat = ref.watch(playerProvider.select((p) => p.repeat));
    final isPlaying = ref.watch(playerProvider.select((p) => p.isPlaying));
    final player = ref.read(playerProvider);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      IconButton(tooltip: 'Перемешать (S)', onPressed: player.toggleShuffle, icon: Icon(Icons.shuffle_rounded, color: shuffle ? accent : theme.colorScheme.onSurface.withOpacity(0.5))),
      IconButton(tooltip: 'Предыдущий (P)', onPressed: player.prev, icon: const Icon(Icons.skip_previous_rounded, size: 34)),
      const SizedBox(width: 6),
      GestureDetector(onTap: player.togglePlay, child: Container(width: 68, height: 68, decoration: BoxDecoration(color: accent, shape: BoxShape.circle), child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.black, size: 38))),
      const SizedBox(width: 6),
      IconButton(tooltip: 'Следующий (N)', onPressed: () => player.next(manual: true), icon: const Icon(Icons.skip_next_rounded, size: 34)),
      IconButton(tooltip: 'Повтор (L)', onPressed: player.cycleRepeat, icon: Icon(repeat == RepeatMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded, color: repeat == RepeatMode.off ? theme.colorScheme.onSurface.withOpacity(0.5) : accent)),
    ]);
  }
}

class _AudioRateVolumeRow extends ConsumerWidget {
  const _AudioRateVolumeRow();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate = ref.watch(playerProvider.select((p) => p.rate));
    final muted = ref.watch(playerProvider.select((p) => p.muted));
    final volume = ref.watch(playerProvider.select((p) => p.volume));
    final player = ref.read(playerProvider);
    final theme = Theme.of(context);
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      PopupMenuButton<double>(tooltip: 'Скорость', onSelected: player.setRate, itemBuilder: (_) => [for (final s in [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]) PopupMenuItem(value: s, child: Text('${s.toStringAsFixed(2)}x'))], child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(border: Border.all(color: theme.dividerColor), borderRadius: BorderRadius.circular(999)), child: Text('${rate.toStringAsFixed(2)}x', style: const TextStyle(fontSize: 12)))),
      const SizedBox(width: 12),
      IconButton(tooltip: 'Без звука (M)', onPressed: player.toggleMute, icon: Icon(muted || volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded, size: 20)),
      SizedBox(width: 120, child: SliderTheme(data: const SliderThemeData(trackHeight: 3, thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6), overlayShape: RoundSliderOverlayShape(overlayRadius: 10)), child: Slider(value: volume.clamp(0, 100), max: 100, onChanged: player.setVolume, activeColor: theme.colorScheme.primary))),
    ]);
  }
}
