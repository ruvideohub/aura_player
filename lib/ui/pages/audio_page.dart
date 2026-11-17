import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../services/settings.dart';
import '../../state/player_controller.dart';
import '../state/ui_state.dart';
import '../widgets/cover_art.dart';
import '../widgets/seekbar.dart';
import '../widgets/visualizer.dart';

class AudioPage extends ConsumerWidget {
  const AudioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final wide = MediaQuery.of(context).size.width >= 1100;

    if (player.current == null || player.hasVideo) {
      return _placeholder(context, ref, theme);
    }

    final nowPlaying = _NowPlaying(player: player, settings: settings);
    final side = _SidePanel(player: player);

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

  Widget _placeholder(BuildContext context, WidgetRef ref, ThemeData theme) {
    final accent = theme.colorScheme.primary;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.music_note_rounded, size: 72, color: accent),
          const SizedBox(height: 16),
          Text('Ничего не играет', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Перетащите файлы в окно, откройте вручную\nили отсканируйте библиотеку.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: () async {
                  const typeGroup = XTypeGroup(
                    label: 'Аудио',
                    extensions: audioExtensions,
                  );
                  try {
                    final files =
                        await openFiles(acceptedTypeGroups: [typeGroup]);
                    if (files.isEmpty) return;
                    final tracks = files
                        .map((f) =>
                            MediaTrack.fromFile(File(f.path), isVideo: false))
                        .toList();
                    await ref.read(playerProvider).open(tracks, 0);
                  } catch (_) {}
                },
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Открыть файлы'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => ref.read(pageProvider.notifier).state = 5,
                child: const Text('Библиотека'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NowPlaying extends StatelessWidget {
  final PlayerController player;
  final SettingsController settings;

  const _NowPlaying({required this.player, required this.settings});

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
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: CoverArt(track: t, size: 280, radius: 24),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                t.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                t.artist.isEmpty
                    ? 'Неизвестный исполнитель'
                    : t.artist,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.65),
                ),
              ),
              if (t.album.isNotEmpty)
                Text(
                  t.album,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withOpacity(0.45),
                  ),
                ),
              const SizedBox(height: 18),
              SizedBox(
                height: 90,
                child: Visualizer(
                  playing: player.isPlaying,
                  mode: settings.visualizerMode,
                  color: accent,
                  opacity: settings.visualizerOpacity,
                ),
              ),
              const SizedBox(height: 14),
              SeekBar(
                position: player.position,
                duration: player.duration,
                onSeek: player.seek,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Перемешать (S)',
                    onPressed: player.toggleShuffle,
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: player.shuffle
                          ? accent
                          : theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Предыдущий (P)',
                    onPressed: player.prev,
                    icon: const Icon(Icons.skip_previous_rounded, size: 34),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: player.togglePlay,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withOpacity(0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        player.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 38,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Следующий (N)',
                    onPressed: () => player.next(manual: true),
                    icon: const Icon(Icons.skip_next_rounded, size: 34),
                  ),
                  IconButton(
                    tooltip: 'Повтор (L)',
                    onPressed: player.cycleRepeat,
                    icon: Icon(
                      player.repeat == RepeatMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color: player.repeat == RepeatMode.off
                          ? theme.colorScheme.onSurface.withOpacity(0.5)
                          : accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PopupMenuButton<double>(
                    tooltip: 'Скорость',
                    onSelected: player.setRate,
                    itemBuilder: (_) => [
                      for (final s in [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0])
                        PopupMenuItem(
                          value: s,
                          child: Text('${s.toStringAsFixed(2)}x'),
                        ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${player.rate.toStringAsFixed(2)}x',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: 'Без звука (M)',
                    onPressed: player.toggleMute,
                    icon: Icon(
                      player.muted || player.volume == 0
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      size: 20,
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 10),
                      ),
                      child: Slider(
                        value: player.volume.clamp(0, 100),
                        max: 100,
                        onChanged: player.setVolume,
                        activeColor: accent,
                      ),
                    ),
                  ),
                ],
              ),
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
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.onSurface,
            unselectedLabelColor:
                theme.colorScheme.onSurface.withOpacity(0.5),
            tabs: const [Tab(text: 'Текст песни'), Tab(text: 'Очередь')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _LyricsView(player: player),
                _QueueView(player: player),
              ],
            ),
          ),
        ],
      ),
    );
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
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }
    final target = (index * 40.0 - 80).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final lyrics = widget.player.lyrics;

    if (lyrics == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lyrics_outlined, size: 44, color: accent),
              const SizedBox(height: 12),
              Text(
                'Текста нет',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Положите файл .lrc с тем же именем рядом\nс аудиофайлом — AURA покажет текст в такт.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.55),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
                  style: TextStyle(
                    fontSize: active ? 17 : 14.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    color: active
                        ? accent
                        : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  child: Text(
                    lyrics.lines[i].text,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
          child: Row(
            children: [
              Text(
                'Очередь · ${player.queue.length}',
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Перемешать (S)',
                onPressed: player.toggleShuffle,
                icon: Icon(
                  Icons.shuffle_rounded,
                  size: 18,
                  color: player.shuffle
                      ? accent
                      : theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              IconButton(
                tooltip: 'Повтор (L)',
                onPressed: player.cycleRepeat,
                icon: Icon(
                  Icons.repeat_rounded,
                  size: 18,
                  color: player.repeat == RepeatMode.off
                      ? theme.colorScheme.onSurface.withOpacity(0.5)
                      : accent,
                ),
              ),
            ],
          ),
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
                  leading: Text(
                    isCurrent
                        ? '▶'
                        : '${i + 1}',
                    style: TextStyle(
                      color: isCurrent ? accent : null,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  title: Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: isCurrent
                        ? TextStyle(color: accent, fontWeight: FontWeight.w600)
                        : null,
                  ),
                  subtitle: Text(
                    t.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => player.removeFromQueue(i),
                  ),
                  onTap: () => player.playAt(i),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
