import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:window_manager/window_manager.dart';

import '../../models/models.dart';
import '../../services/library.dart';
import '../../state/player_controller.dart';
import '../pages/audio_page.dart';
import '../pages/equalizer_page.dart';
import '../pages/library_page.dart';
import '../pages/playlists_page.dart';
import '../pages/settings_page.dart';
import '../pages/video_page.dart';
import '../state/ui_state.dart';
import '../widgets/cover_art.dart';
import '../widgets/seekbar.dart';

bool get _isDesktop =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _dragOver = false;
  final FocusNode _shortcutFocus = FocusNode(debugLabel: 'shortcuts');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Загружаем библиотеку
      await ref.read(libraryProvider).load();
      // Применяем эквалайзер
      ref.read(playerProvider).applyEqualizer();
      // Автозапрос разрешений и скан на Android
      if (! _isDesktop && mounted) {
        await _ensureAndroidPermissionsAndScan();
      }
    });
  }

  Future<void> _ensureAndroidPermissionsAndScan() async {
    try {
      // Проверяем, нужна ли нам проверка разрешений
      final lib = ref.read(libraryProvider);
      // Если библиотека пустая — пробуем запросить разрешения и отсканировать
      if (lib.audio.isEmpty && lib.video.isEmpty) {
        final hasPermission = await _requestMediaPermissions(showRationale: false);
        if (hasPermission) {
          await lib.scan();
        }
      }
    } catch (_) {}
  }

  Future<bool> _requestMediaPermissions({bool showRationale = true}) async {
    try {
      if (_isDesktop) return true;
      
      // Android 13+ : READ_MEDIA_AUDIO / READ_MEDIA_VIDEO
      // Android <13 : READ_EXTERNAL_STORAGE
      // permission_handler мапит их на Permission.storage / photos / videos
      List<Permission> toRequest = [];
      
      if (Platform.isAndroid) {
        // Пробуем запросить все возможные
        // На Android 13+ нужны photos/videos, на старых - storage
        toRequest = [Permission.storage];
        // На новых версиях также запрашиваем audio/photos
        // permission_handler 11+ поддерживает .audio, .videos
        try {
          toRequest.add(Permission.audio);
          toRequest.add(Permission.videos);
          toRequest.add(Permission.photos);
        } catch (_) {}
      }
      
      final statuses = await toRequest.request();
      // Считаем что хотя бы одно разрешение получено
      final granted = statuses.values.any((s) => s.isGranted || s.isLimited);
      return granted;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _shortcutFocus.dispose();
    super.dispose();
  }

  void _openDropped(List<String> paths) {
    final player = ref.read(playerProvider);
    final audioPaths = paths.where(isAudioPath).toList();
    final videoPaths = paths.where(isVideoPath).toList();
    if (videoPaths.isNotEmpty) {
      final tracks = videoPaths
          .map((p) => MediaTrack.fromFile(File(p), isVideo: true))
          .toList();
      player.open(tracks, 0);
      ref.read(pageProvider.notifier).state = 1;
    } else if (audioPaths.isNotEmpty) {
      final tracks = audioPaths
          .map((p) => MediaTrack.fromFile(File(p), isVideo: false))
          .toList();
      player.open(tracks, 0);
      ref.read(pageProvider.notifier).state = 0;
    }
  }

  Future<void> _pickFiles() async {
    const typeGroup = XTypeGroup(
      label: 'Медиа',
      extensions: [...audioExtensions, ...videoExtensions],
    );
    try {
      final files = await openFiles(acceptedTypeGroups: [typeGroup]);
      _openDropped(files.map((f) => f.path).toList());
    } catch (_) {}
  }

  bool _isTyping() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    final w = ctx.widget;
    if (w is EditableText) return true;
    return false;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_isTyping()) return KeyEventResult.ignored;

    final player = ref.read(playerProvider);
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.space) {
      player.togglePlay();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      player.seek(player.position + const Duration(seconds: 5));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      player.seek(player.position - const Duration(seconds: 5));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      player.setVolume(player.volume + 5);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      player.setVolume(player.volume - 5);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyM) {
      player.toggleMute();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyN) {
      player.next(manual: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyP) {
      player.prev();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyL) {
      player.cycleRepeat();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyS) {
      player.toggleShuffle();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF) {
      _toggleFullscreen();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.bracketLeft) {
      player.setRate(player.rate - 0.25);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.bracketRight) {
      player.setRate(player.rate + 0.25);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _toggleFullscreen() async {
    if (!_isDesktop) return;
    final fs = !ref.read(fullscreenProvider);
    ref.read(fullscreenProvider.notifier).state = fs;
    try {
      await windowManager.setFullScreen(fs);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final pageIndex = ref.watch(pageProvider);
    final fullscreen = ref.watch(fullscreenProvider);
    final player = ref.watch(playerProvider);
    // Стабильный wide без дёрганий: используем LayoutBuilder
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final showMiniPlayer = _shouldShowMiniPlayer(pageIndex, player, fullscreen);

        // Автопереход на вкладку видео при воспроизведении видео
        ref.listen(playerProvider.select((p) => p.hasVideo), (prev, next) {
          if (next && !fullscreen) {
            ref.read(pageProvider.notifier).state = 1;
          }
        });

        final pages = IndexedStack(
          index: pageIndex,
          children: const [
            AudioPage(),
            VideoPage(),
            LibraryPage(),
            PlaylistsPage(),
            EqualizerPage(),
            SettingsPage(),
          ],
        );

        Widget content;
        if (fullscreen) {
          content = pages;
        } else {
          content = Row(
            children: [
              if (wide) _Sidebar(selected: pageIndex),
              Expanded(child: pages),
            ],
          );
        }

        // Основная колонка с фиксированными высотами (не скачет)
        Widget shell = Column(
          children: [
            if (!fullscreen && _isDesktop) _TitleBar(onPickFiles: _pickFiles),
            Expanded(child: content),
            // Мини-плеер только на второстепенных вкладках (исправлено дублирование)
            if (showMiniPlayer)
              SizedBox(
                height: 76,
                child: _MiniPlayer(
                  compact: !wide,
                  onOpenPlayer: () {
                    ref.read(pageProvider.notifier).state =
                        player.hasVideo ? 1 : 0;
                  },
                ),
              ),
            // Мобильная навигация с фиксированной высотой (не скачет)
            if (!fullscreen && !wide)
              SizedBox(
                height: 80,
                child: _MobileNav(selected: pageIndex),
              ),
          ],
        );

        // Drag & Drop
        shell = DropTarget(
          onDragDone: (d) => _openDropped(d.files.map((f) => f.path).toList()),
          onDragEntered: (_) => setState(() => _dragOver = true),
          onDragExited: (_) => setState(() => _dragOver = false),
          child: Stack(
            children: [
              Positioned.fill(child: shell),
              if (_dragOver)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.10),
                      child: Center(
                        child: Icon(
                          Icons.add_circle_outline_rounded,
                          size: 72,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );

        // SafeArea для статус-бара на Android (фикс отступов)
        final scaffold = Scaffold(
          body: SafeArea(
            top: !_isDesktop, // на Android/iOS учитываем статус-бар
            bottom: false, // низ обрабатываем сами (навбар)
            child: Focus(
              focusNode: _shortcutFocus,
              autofocus: true,
              onKeyEvent: _onKey,
              child: shell,
            ),
          ),
        );

        // На десктопе без SafeArea (там свой тайтлбар)
        if (_isDesktop) {
          return Scaffold(
            body: Focus(
              focusNode: _shortcutFocus,
              autofocus: true,
              onKeyEvent: _onKey,
              child: shell,
            ),
          );
        }
        return scaffold;
      },
    );
  }

  // Логика показа мини-плеера: не показываем его на полноэкранных плеерах
  bool _shouldShowMiniPlayer(int pageIndex, PlayerController player, bool fullscreen) {
    if (fullscreen) return false;
    if (player.current == null) return false;
    // Если сейчас открыт полноэкранный плеер (Аудио или Видео) — мини не нужен (дублирование)
    if (pageIndex == 0 && !player.hasVideo) return false; // на странице Музыка уже есть большой плеер
    if (pageIndex == 1 && player.hasVideo) return false; // на странице Видео уже есть плеер
    // На остальных вкладках (библиотека, плейлисты, EQ, настройки) показываем мини
    return true;
  }
}

// ---------------- Тайтлбар ----------------

class _TitleBar extends StatelessWidget {
  final VoidCallback onPickFiles;

  const _TitleBar({required this.onPickFiles});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      height: 42,
      color: isDark ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.7),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.graphic_eq_rounded,
              size: 14,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'AURA Player',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          IconButton(
            tooltip: 'Добавить файлы',
            onPressed: onPickFiles,
            icon: const Icon(Icons.add, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: DragToMoveArea(child: SizedBox.expand()),
          ),
          _WindowButton(
            icon: Icons.remove,
            onTap: () => windowManager.minimize(),
          ),
          _WindowButton(
            icon: Icons.crop_square,
            onTap: () async {
              if (await windowManager.isMaximized()) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
          ),
          _WindowButton(
            icon: Icons.close,
            onTap: () => windowManager.destroy(),
            hoverColor: Colors.red,
          ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? hoverColor;

  const _WindowButton({
    required this.icon,
    required this.onTap,
    this.hoverColor,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final fg = _hover
        ? (widget.hoverColor ?? Theme.of(context).colorScheme.onSurface)
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 46,
          height: 42,
          child: Icon(widget.icon, size: 16, color: fg),
        ),
      ),
    );
  }
}

// ---------------- Сайдбар ----------------

class _Sidebar extends ConsumerWidget {
  final int selected;

  const _Sidebar({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    const items = [
      (0, Icons.music_note_rounded, 'Музыка'),
      (1, Icons.movie_outlined, 'Видео'),
      (2, Icons.library_music_outlined, 'Библиотека'),
      (3, Icons.queue_music_outlined, 'Плейлисты'),
      (4, Icons.equalizer_rounded, 'Эквалайзер'),
      (5, Icons.settings_outlined, 'Настройки'),
    ];

    return Container(
      width: 232,
      color: isDark ? Colors.black.withOpacity(0.35) : Colors.white.withOpacity(0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    size: 20,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AURA Player',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: Material(
                color: selected == item.$1
                    ? accent.withOpacity(0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => ref.read(pageProvider.notifier).state = item.$1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.$2,
                          size: 20,
                          color: selected == item.$1
                              ? accent
                              : theme.colorScheme.onSurface.withOpacity(0.55),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          item.$3,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: selected == item.$1
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: selected == item.$1
                                ? accent
                                : theme.colorScheme.onSurface.withOpacity(0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _AddFilesButton(),
          ),
        ],
      ),
    );
  }
}

class _AddFilesButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const typeGroup = XTypeGroup(
      label: 'Медиа',
      extensions: [...audioExtensions, ...videoExtensions],
    );
    return OutlinedButton.icon(
      onPressed: () async {
        try {
          final files = await openFiles(acceptedTypeGroups: [typeGroup]);
          if (files.isEmpty) return;
          final player = ref.read(playerProvider);
          final audioPaths =
              files.map((f) => f.path).where(isAudioPath).toList();
          final videoPaths =
              files.map((f) => f.path).where(isVideoPath).toList();
          if (videoPaths.isNotEmpty) {
            final tracks = videoPaths
                .map((p) => MediaTrack.fromFile(File(p), isVideo: true))
                .toList();
            await player.open(tracks, 0);
            ref.read(pageProvider.notifier).state = 1;
          } else if (audioPaths.isNotEmpty) {
            final tracks = audioPaths
                .map((p) => MediaTrack.fromFile(File(p), isVideo: false))
                .toList();
            await player.open(tracks, 0);
            ref.read(pageProvider.notifier).state = 0;
          }
        } catch (_) {}
      },
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Открыть файлы'),
    );
  }
}

// ---------------- Мини-плеер ----------------

class _MiniPlayer extends ConsumerWidget {
  final bool compact;
  final VoidCallback onOpenPlayer;

  const _MiniPlayer({required this.compact, required this.onOpenPlayer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final t = player.current!;

    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.black.withOpacity(0.55)
            : Colors.white.withOpacity(0.7),
        border: Border(
          top: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onOpenPlayer,
            child: CoverArt(track: t, size: 48, radius: 10),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: compact ? 4 : 3,
            child: GestureDetector(
              onTap: onOpenPlayer,
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    t.artist.isEmpty ? 'AURA Player' : t.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: compact ? 5 : 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SeekBar(
                position: player.position,
                duration: player.duration,
                onSeek: player.seek,
                compact: true,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Предыдущий (P)',
            onPressed: player.prev,
            icon: const Icon(Icons.skip_previous_rounded),
          ),
          _PlayButton(size: 44),
          IconButton(
            tooltip: 'Следующий (N)',
            onPressed: () => player.next(manual: true),
            icon: const Icon(Icons.skip_next_rounded),
          ),
          if (!compact)
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 12),
              child: Row(
                children: [
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
                    width: 100,
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
            ),
        ],
      ),
    );
  }
}

class _PlayButton extends ConsumerWidget {
  final double size;

  const _PlayButton({required this.size});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: player.togglePlay,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.black,
          size: size * 0.6,
        ),
      ),
    );
  }
}

// ---------------- Мобильная навигация (фикс скачков) ----------------

class _MobileNav extends ConsumerWidget {
  final int selected;

  const _MobileNav({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const items = [
      (0, Icons.music_note_rounded, 'Музыка'),
      (1, Icons.movie_outlined, 'Видео'),
      (2, Icons.library_music_outlined, 'Библиотека'),
      (3, Icons.queue_music_outlined, 'Плейлисты'),
      (4, Icons.equalizer_rounded, 'Эквалайзер'),
      (5, Icons.settings_outlined, 'Настройки'),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: NavigationBar(
        height: 80,
        selectedIndex: selected,
        onDestinationSelected: (i) =>
            ref.read(pageProvider.notifier).state = i,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final item in items)
            NavigationDestination(
              icon: Icon(item.$2),
              selectedIcon: Icon(item.$2, color: Theme.of(context).colorScheme.primary),
              label: item.$3,
            ),
        ],
      ),
    );
  }
}
