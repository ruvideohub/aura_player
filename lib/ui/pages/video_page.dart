import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

import '../../models/models.dart';
import '../../state/player_controller.dart';
import '../state/ui_state.dart';
import '../widgets/seekbar.dart';

bool get _isDesktop =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

class VideoPage extends ConsumerStatefulWidget {
  const VideoPage({super.key});

  @override
  ConsumerState<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends ConsumerState<VideoPage> {
  bool _controlsVisible = true;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _showControls(PlayerController player) {
    _hideTimer?.cancel();
    setState(() => _controlsVisible = true);
    if (player.isPlaying) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && ref.read(playerProvider).isPlaying) {
          setState(() => _controlsVisible = false);
        }
      });
    }
  }

  Future<void> _toggleFullscreen() async {
    if (!_isDesktop) return;
    final fs = !ref.read(fullscreenProvider);
    ref.read(fullscreenProvider.notifier).state = fs;
    try {
      await windowManager.setFullScreen(fs);
    } catch (_) {}
  }

  Future<void> _openVideo() async {
    const typeGroup = XTypeGroup(label: 'Видео', extensions: videoExtensions);
    try {
      final files = await openFiles(acceptedTypeGroups: [typeGroup]);
      if (files.isEmpty) return;
      final tracks = files
          .map((f) => MediaTrack.fromFile(File(f.path), isVideo: true))
          .toList();
      await ref.read(playerProvider).open(tracks, 0);
      ref.read(pageProvider.notifier).state = 1;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final theme = Theme.of(context);
    final current = player.current;

    if (current == null || !player.hasVideo) {
      return _placeholder(theme);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Адаптивное видео: Media3 SurfaceView на Android, libmpv на десктопе
        // PlayerController.buildVideoView инкапсулирует выбор бэкенда
        // и избегает молчаливого вылета libmpv на Android (content://)
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black,
            child: player.buildVideoView(),
          ),
        ),
        StreamBuilder<bool>(
          stream: player.bufferingStream,
          builder: (context, snap) {
            if (snap.data != true) return const SizedBox.shrink();
            return const Center(
              child: SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            );
          },
        ),
        // Жесты поверх видео
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_controlsVisible) {
                setState(() => _controlsVisible = false);
              } else {
                _showControls(player);
              }
            },
            onDoubleTap: _toggleFullscreen,
            onHorizontalDragUpdate: (d) {
              final delta = Duration(milliseconds: (d.delta.dx * 90).round());
              player.seek(player.position + delta);
              _showControls(player);
            },
            child: MouseRegion(
              onHover: (_) => _showControls(player),
            ),
          ),
        ),
        // Оверлей управления
        IgnorePointer(
          ignoring: !_controlsVisible,
          child: AnimatedOpacity(
            opacity: _controlsVisible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Column(
              children: [
                _topBar(context, player, current),
                const Spacer(),
                _bottomBar(context, player),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _topBar(BuildContext context, PlayerController player, MediaTrack t) {
    final isAndroid = player.isAndroid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.65), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              t.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          _speedMenu(context, player),
          // На Android аудиодорожки/субтитры Media3 пока скрываем — нет вылета
          if (!isAndroid) ...[
            IconButton(
              tooltip: 'Аудиодорожка',
              icon: const Icon(Icons.audiotrack_rounded, color: Colors.white),
              onPressed: () => _audioTrackMenu(context, player),
            ),
            IconButton(
              tooltip: 'Субтитры',
              icon: const Icon(Icons.subtitles_outlined, color: Colors.white),
              onPressed: () => _subtitleMenu(context, player),
            ),
          ] else
            // На Android показываем подсказку
            Tooltip(
              message: 'Дорожки/субтитры — в разработке (Media3)',
              child: IconButton(
                icon: const Icon(Icons.subtitles_outlined, color: Colors.white38),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Дорожки скоро будут на Media3')),
                  );
                },
              ),
            ),
          IconButton(
            tooltip: 'Полный экран (F)',
            icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
            onPressed: _toggleFullscreen,
          ),
        ],
      ),
    );
  }

  Widget _speedMenu(BuildContext context, PlayerController player) {
    const speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    return PopupMenuButton<double>(
      tooltip: 'Скорость',
      icon: const Icon(Icons.speed_rounded, color: Colors.white),
      onSelected: player.setRate,
      itemBuilder: (_) => [
        for (final s in speeds)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                if (player.rate == s)
                  Icon(
                    Icons.check,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  )
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text('${s.toStringAsFixed(2)}x'),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _audioTrackMenu(
      BuildContext context, PlayerController player) async {
    final tracks = player.audioTracks;
    if (tracks.isEmpty) return;
    final selectedId = player.selectedAudioTrackId;
    final chosen = await showMenu<AudioTrack>(
      context: context,
      position: const RelativeRect.fromLTRB(200, 60, 40, 300),
      items: [
        for (var i = 0; i < tracks.length; i++)
          PopupMenuItem(
            value: tracks[i],
            child: Row(
              children: [
                Icon(
                  selectedId == tracks[i].id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tracks[i].title?.isNotEmpty == true
                        ? tracks[i].title!
                        : (tracks[i].language?.isNotEmpty == true
                            ? tracks[i].language!
                            : 'Дорожка ${i + 1}'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    if (chosen != null) await player.selectAudioTrack(chosen);
  }

  Future<void> _subtitleMenu(
      BuildContext context, PlayerController player) async {
    final tracks = player.subtitleTracks;
    final selectedId = player.selectedSubtitleTrackId;
    final theme = Theme.of(context);
    final chosen = await showMenu<Object>(
      context: context,
      position: const RelativeRect.fromLTRB(240, 60, 20, 300),
      items: [
        const PopupMenuItem(
          value: 'off',
          child: Text('Выключены'),
        ),
        const PopupMenuItem(
          value: 'external',
          child: Text('Загрузить файл…'),
        ),
        for (final t in tracks)
          PopupMenuItem(
            value: t,
            child: Row(
              children: [
                Icon(
                  selectedId == t.id && t.id != 'no' && t.id != 'auto'
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.title?.isNotEmpty == true
                        ? t.title!
                        : (t.language?.isNotEmpty == true
                            ? t.language!
                            : 'Дорожка'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    if (chosen is String && chosen == 'off') {
      await player.selectSubtitleOff();
    } else if (chosen is String && chosen == 'external') {
      const typeGroup = XTypeGroup(
        label: 'Субтитры',
        extensions: ['srt', 'ass', 'ssa', 'vtt'],
      );
      try {
        final file = await openFile(acceptedTypeGroups: [typeGroup]);
        if (file != null) await player.loadExternalSubtitle(file.path);
      } catch (_) {}
    } else if (chosen is SubtitleTrack) {
      await player.selectSubtitleTrack(chosen);
    }
  }

  Widget _bottomBar(BuildContext context, PlayerController player) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.65), Colors.transparent],
        ),
      ),
      child: Column(
        children: [
          SeekBar(
            position: player.position,
            duration: player.duration,
            onSeek: player.seek,
            compact: true,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              IconButton(
                tooltip: 'Предыдущий (P)',
                onPressed: player.prev,
                icon:
                    const Icon(Icons.skip_previous_rounded, color: Colors.white),
              ),
              GestureDetector(
                onTap: player.togglePlay,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    player.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 30,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Следующий (N)',
                onPressed: () => player.next(manual: true),
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Без звука (M)',
                onPressed: player.toggleMute,
                icon: Icon(
                  player.muted || player.volume == 0
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(
                width: 110,
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
                    activeColor: theme.colorScheme.primary,
                    inactiveColor: Colors.white24,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Полный экран (F)',
                onPressed: _toggleFullscreen,
                icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder(ThemeData theme) {
    final accent = theme.colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surface,
            accent.withOpacity(0.06),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_display_outlined, size: 72, color: accent),
            const SizedBox(height: 16),
            Text('Видео не открыто', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Перетащите файл в окно или откройте вручную.\nПоддерживаются MKV, MP4, HEVC, AV1 и другие форматы.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openVideo,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Открыть видео'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.read(pageProvider.notifier).state = 5,
              child: const Text('Настроить папки сканирования'),
            ),
          ],
        ),
      ),
    );
  }
}
