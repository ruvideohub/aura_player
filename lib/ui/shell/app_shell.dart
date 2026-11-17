import 'dart:async';
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
import '../../services/native_bridge.dart';
import '../../state/player_controller.dart';
import '../pages/audio_page.dart';
import '../pages/equalizer_page.dart';
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

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  bool _dragOver = false;
  final FocusNode _shortcutFocus = FocusNode(debugLabel: 'shortcuts');
  StreamSubscription<String>? _mediaSub;
  StreamSubscription<String>? _openFileSub;
  bool _inPip = false;
  Timer? _notifTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NativeBridge.ensureHandler();
    _mediaSub = NativeBridge.mediaActions.listen(_handleMediaAction);
    _openFileSub = NativeBridge.openFileRequests.listen(_handleOpenFile);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(libraryProvider).load();
      ref.read(playerProvider).applyEqualizer();
      if (!_isDesktop && mounted) {
        await _ensureAndroidPermissionsAndScan();
      }
      // уведомление о разрешении
      if (!_isDesktop) {
        try { await NativeBridge.requestNotifPermission(); } catch (_) {}
      }
      // холодный старт VIEW — Открыть с помощью (повторно страхуем)
      if (!_isDesktop) {
        try {
          final pending = await NativeBridge.consumeInitialOpen();
          if (pending != null && pending.isNotEmpty && mounted) {
            await Future.delayed(const Duration(milliseconds: 400));
            _handleOpenFile(pending);
          }
        } catch (_) {}
      }
    });

    // слушаем изменения плеера чтобы обновлять уведомление/виджет только для музыки
    ref.listenManual(playerProvider.select((p) => p.current?.path), (prev, next) {
      _syncNotification();
    });
    ref.listenManual(playerProvider.select((p) => p.isPlaying), (prev, next) {
      _syncNotification();
    });
  }

  void _handleMediaAction(String a) async {
    final player = ref.read(playerProvider);
    switch (a) {
      case 'AURA_TOGGLE':
        await player.togglePlay();
        break;
      case 'AURA_NEXT':
        await player.next(manual: true);
        break;
      case 'AURA_PREV':
        await player.prev();
        break;
      case 'AURA_STOP':
        await player.pauseForStop();
        await NativeBridge.hideNotification();
        break;
      case 'AURA_LEAVE_HINT':
        // авто-PiP для видео (кнопка + авто)
        if (!_isDesktop && player.hasVideo && player.isPlaying && !_inPip) {
          final c = player.androidVideoController;
          final w = c?.value.size.width?.toInt() ?? 16;
          final h = c?.value.size.height?.toInt() ?? 9;
          // не вызываем если аудио — только видео
          try {
            final ok = await NativeBridge.enterPip(width: w, height: h);
            if (ok) setState(() => _inPip = true);
          } catch (_) {}
        }
        break;
      case 'AURA_PIP_ENTER':
        setState(() => _inPip = true);
        break;
      case 'AURA_PIP_EXIT':
        setState(() => _inPip = false);
        // выйти из фуллскрина если был
        if (ref.read(fullscreenProvider)) {
          ref.read(fullscreenProvider.notifier).state = false;
        }
        break;
    }
    // после любого действия обновляем уведомление
    _syncNotification();
  }

  void _syncNotification() {
    final player = ref.read(playerProvider);
    final cur = player.current;
    if (cur == null) {
      // нет трека — прячем
      NativeBridge.hideNotification();
      _notifTimer?.cancel();
      return;
    }
    // ТОЛЬКО для музыки — видео не показываем в шторке
    if (cur.isVideo) {
      NativeBridge.hideNotification();
      _notifTimer?.cancel();
      return;
    }
    // музыка — показываем/обновляем
    final isPlaying = player.isPlaying;
    final title = cur.title;
    final artist = cur.artist.isEmpty ? (cur.album.isEmpty ? 'AURA Player' : cur.album) : cur.artist;
    final pos = player.position.inMilliseconds;
    final dur = player.duration.inMilliseconds;

    // сразу
    NativeBridge.updateNotification(title: title, artist: artist, isPlaying: isPlaying, pos: pos, dur: dur);

    // периодическое обновление прогресса виджета/уведомления когда играет
    _notifTimer?.cancel();
    if (isPlaying) {
      _notifTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final p = ref.read(playerProvider);
        if (p.current?.path != cur.path) { _notifTimer?.cancel(); return; }
        if (!p.isPlaying) { _notifTimer?.cancel(); _syncNotification(); return; }
        NativeBridge.updateNotification(
          title: p.current?.title ?? title,
          artist: p.current?.artist ?? artist,
          isPlaying: true,
          pos: p.position.inMilliseconds,
          dur: p.duration.inMilliseconds,
        );
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final player = ref.read(playerProvider);
    if (state == AppLifecycleState.paused) {
      player.setBackground(true);
      if (player.current?.isVideo == false && player.isPlaying) {
        _syncNotification();
      }
    } else if (state == AppLifecycleState.resumed) {
      player.setBackground(false);
      _syncNotification();
    } else if (state == AppLifecycleState.inactive) {}
  }

  Future<void> _ensureAndroidPermissionsAndScan() async {
    try {
      final lib = ref.read(libraryProvider);
      if (lib.audio.isEmpty && lib.video.isEmpty) {
        final hasPermission = await _requestMediaPermissions(showRationale: false);
        if (hasPermission) await lib.scan();
      }
    } catch (_) {}
  }

  Future<bool> _requestMediaPermissions({bool showRationale = true}) async {
    try {
      if (_isDesktop) return true;
      List<Permission> toRequest = [];
      if (Platform.isAndroid) {
        toRequest = [Permission.storage];
        try {
          toRequest.add(Permission.audio);
          toRequest.add(Permission.videos);
          toRequest.add(Permission.photos);
        } catch (_) {}
        // уведомление для Android 13+
        try { toRequest.add(Permission.notification); } catch (_) {}
      }
      final statuses = await toRequest.request();
      return statuses.values.any((s) => s.isGranted || s.isLimited);
    } catch (_) { return false; }
  }

  Future<void> _handleOpenFile(String raw) async {
    final path = raw.trim();
    if (path.isEmpty) return;
    // защита от дублей — иногда и VIEW и consume дают один и тот же uri
    // просто открываем; PlayerController сам заменит очередь
    final isStream = isStreamUrl(path) || path.contains('.m3u8') || path.contains('.mpd');
    final ext = extOf(path).toLowerCase();
    // контент без расширения — считаем видео если не аудио
    bool isVideo;
    if (isStream) {
      isVideo = true;
    } else if (path.startsWith('content://')) {
      // по расширению если есть, иначе эвристика по mime не доступна — пробуем видео по умолчанию,
      // аудио контент обычно .mp3/.flac и расширение сохраняется в uri
      if (audioExtensions.contains(ext)) isVideo = false;
      else if (videoExtensions.contains(ext) || ext.isEmpty) isVideo = true;
      else isVideo = isVideoPath(path);
    } else {
      isVideo = isVideoPath(path);
      if (!isVideo && !isAudioPath(path)) {
        // неизвестный — считаем видео
        isVideo = true;
      }
    }

    try {
      final track = path.startsWith('http://') || path.startsWith('https://') || path.startsWith('rtmp://') || path.startsWith('rtsp://') || path.startsWith('content://')
          ? MediaTrack.fromUrl(path, isVideo: isVideo)
          : MediaTrack.fromFile(File(path.startsWith('file://') ? Uri.parse(path).toFilePath() : path), isVideo: isVideo);
      ref.read(libraryProvider).importTracks([track]);
      await ref.read(playerProvider).open([track], 0);
      ref.read(pageProvider.notifier).state = isVideo ? 1 : 0;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось открыть: $e')));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mediaSub?.cancel();
    _openFileSub?.cancel();
    _notifTimer?.cancel();
    _shortcutFocus.dispose();
    super.dispose();
  }

  void _openDropped(List<String> paths) {
    final player = ref.read(playerProvider);
    final lib = ref.read(libraryProvider);
    final audioPaths = paths.where(isAudioPath).toList();
    final videoPaths = paths.where(isVideoPath).toList();
    if (videoPaths.isNotEmpty) {
      final tracks = videoPaths.map((p) => MediaTrack.fromFile(File(p), isVideo: true)).toList();
      lib.importTracks(tracks);
      player.open(tracks, 0);
      ref.read(pageProvider.notifier).state = 1;
    } else if (audioPaths.isNotEmpty) {
      final tracks = audioPaths.map((p) => MediaTrack.fromFile(File(p), isVideo: false)).toList();
      lib.importTracks(tracks);
      player.open(tracks, 0);
      ref.read(pageProvider.notifier).state = 0;
    }
  }

  Future<void> _pickFiles() async {
    const typeGroup = XTypeGroup(label: 'Медиа', extensions: [...audioExtensions, ...videoExtensions]);
    try {
      final files = await openFiles(acceptedTypeGroups: [typeGroup]);
      if (files.isEmpty) return;
      _openDropped(files.map((f) => f.path).toList());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка выбора файлов: $e')));
    }
  }

  bool _isTyping() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    final w = ctx.widget;
    if (w is EditableText) return true;
    return false;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (_isTyping()) return KeyEventResult.ignored;
    final player = ref.read(playerProvider);
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) { player.togglePlay(); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.arrowRight) { player.seek(player.position + const Duration(seconds: 5)); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.arrowLeft) { player.seek(player.position - const Duration(seconds: 5)); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.arrowUp) { player.setVolume(player.volume + 5); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.arrowDown) { player.setVolume(player.volume - 5); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.keyM) { player.toggleMute(); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.keyN) { player.next(manual: true); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.keyP) { player.prev(); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.keyL) { player.cycleRepeat(); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.keyS) { player.toggleShuffle(); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.keyF) { _toggleFullscreen(); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.bracketLeft) { player.setRate(player.rate - 0.25); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.bracketRight) { player.setRate(player.rate + 0.25); return KeyEventResult.handled; }
    return KeyEventResult.ignored;
  }

  Future<void> _toggleFullscreen() async {
    final fs = !ref.read(fullscreenProvider);
    ref.read(fullscreenProvider.notifier).state = fs;
    if (_isDesktop) {
      try { await windowManager.setFullScreen(fs); } catch (_) {}
    } else {
      try {
        if (fs) {
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } else {
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageIndex = ref.watch(pageProvider);
    final fullscreen = ref.watch(fullscreenProvider);
    final player = ref.watch(playerProvider);

    // В PiP — показываем только видео без контролов
    if (_inPip && player.hasVideo) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: player.buildVideoView(fit: ref.watch(videoFitProvider))),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 980;
      final showMiniPlayer = _shouldShowMiniPlayer(pageIndex, player, fullscreen);

      ref.listen(playerProvider.select((p) => p.hasVideo), (prev, next) {
        if (next == true && !fullscreen) ref.read(pageProvider.notifier).state = 1;
      });

      final pages = IndexedStack(index: pageIndex, children: const [
        AudioPage(),
        VideoPage(),
        PlaylistsPage(),
        EqualizerPage(),
        SettingsPage(),
      ]);

      Widget content;
      if (fullscreen) {
        content = pages;
      } else {
        content = Row(children: [if (wide) _Sidebar(selected: pageIndex), Expanded(child: pages)]);
      }

      if (fullscreen && pageIndex == 1) {
        final videoShell = DropTarget(
          onDragDone: (d) => _openDropped(d.files.map((f) => f.path).toList()),
          onDragEntered: (_) => setState(() => _dragOver = true),
          onDragExited: (_) => setState(() => _dragOver = false),
          child: Stack(children: [
            Positioned.fill(child: pages),
            if (_dragOver) Positioned.fill(child: IgnorePointer(child: Container(color: Theme.of(context).colorScheme.primary.withOpacity(0.10), child: Center(child: Icon(Icons.add_circle_outline_rounded, size: 72, color: Theme.of(context).colorScheme.primary))))),
          ]),
        );
        return Scaffold(
          backgroundColor: Colors.black,
          body: Focus(focusNode: _shortcutFocus, autofocus: true, onKeyEvent: _onKey, child: videoShell),
        );
      }

      Widget shell = Column(children: [
        if (!fullscreen && _isDesktop) _TitleBar(onPickFiles: _pickFiles),
        Expanded(child: ColoredBox(color: pageIndex == 1 ? Colors.black : Colors.transparent, child: content)),
        if (showMiniPlayer) SizedBox(height: 76, child: _MiniPlayer(compact: !wide, onOpenPlayer: () { ref.read(pageProvider.notifier).state = player.hasVideo ? 1 : 0; })),
        if (!fullscreen && !wide) SizedBox(height: 80, child: _MobileNav(selected: pageIndex)),
      ]);

      shell = DropTarget(
        onDragDone: (d) => _openDropped(d.files.map((f) => f.path).toList()),
        onDragEntered: (_) => setState(() => _dragOver = true),
        onDragExited: (_) => setState(() => _dragOver = false),
        child: Stack(children: [Positioned.fill(child: shell), if (_dragOver) Positioned.fill(child: IgnorePointer(child: Container(color: Theme.of(context).colorScheme.primary.withOpacity(0.10), child: Center(child: Icon(Icons.add_circle_outline_rounded, size: 72, color: Theme.of(context).colorScheme.primary)))))]),
      );

      final scaffold = Scaffold(
        backgroundColor: pageIndex == 1 ? Colors.black : null,
        body: SafeArea(top: !_isDesktop, bottom: false, child: Focus(focusNode: _shortcutFocus, autofocus: true, onKeyEvent: _onKey, child: shell)),
      );
      if (_isDesktop) {
        return Scaffold(backgroundColor: pageIndex == 1 ? Colors.black : null, body: Focus(focusNode: _shortcutFocus, autofocus: true, onKeyEvent: _onKey, child: shell));
      }
      return scaffold;
    });
  }

  bool _shouldShowMiniPlayer(int pageIndex, PlayerController player, bool fullscreen) {
    if (fullscreen) return false;
    if (player.current == null) return false;
    if (pageIndex == 0 && !player.hasVideo) return false;
    if (pageIndex == 1 && player.hasVideo) return false;
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
    return Container(height: 42, color: isDark ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.7), child: Row(children: [
      const SizedBox(width: 12),
      Container(width: 22, height: 22, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.graphic_eq_rounded, size: 14, color: Colors.black)),
      const SizedBox(width: 10),
      const Text('AURA Player', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      const SizedBox(width: 8),
      IconButton(tooltip: 'Добавить файлы', onPressed: onPickFiles, icon: const Icon(Icons.add, size: 18), visualDensity: VisualDensity.compact),
      Expanded(child: DragToMoveArea(child: SizedBox.expand())),
      _WindowButton(icon: Icons.remove, onTap: () => windowManager.minimize()),
      _WindowButton(icon: Icons.crop_square, onTap: () async { if (await windowManager.isMaximized()) await windowManager.unmaximize(); else await windowManager.maximize(); }),
      _WindowButton(icon: Icons.close, onTap: () => windowManager.destroy(), hoverColor: Colors.red),
    ]));
  }
}
class _WindowButton extends StatefulWidget {
  final IconData icon; final VoidCallback onTap; final Color? hoverColor;
  const _WindowButton({required this.icon, required this.onTap, this.hoverColor});
  @override
  State<_WindowButton> createState() => _WindowButtonState();
}
class _WindowButtonState extends State<_WindowButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final fg = _hover ? (widget.hoverColor ?? Theme.of(context).colorScheme.onSurface) : Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    return MouseRegion(onEnter: (_) => setState(() => _hover = true), onExit: (_) => setState(() => _hover = false), child: GestureDetector(onTap: widget.onTap, child: SizedBox(width: 46, height: 42, child: Icon(widget.icon, size: 16, color: fg))));
  }
}

// ---------------- Сайдбар — 5 пунктов без дублирования ----------------
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
      (2, Icons.queue_music_outlined, 'Плейлисты'),
      (3, Icons.equalizer_rounded, 'Эквалайзер'),
      (4, Icons.settings_outlined, 'Настройки'),
    ];
    return Container(width: 232, color: isDark ? Colors.black.withOpacity(0.35) : Colors.white.withOpacity(0.5), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 12),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.graphic_eq_rounded, size: 20, color: Colors.black)), const SizedBox(width: 10), Expanded(child: Text('AURA Player', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)))])),
      const SizedBox(height: 14),
      for (final item in items) Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), child: Material(color: selected == item.$1 ? accent.withOpacity(0.14) : Colors.transparent, borderRadius: BorderRadius.circular(12), child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () => ref.read(pageProvider.notifier).state = item.$1, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), child: Row(children: [Icon(item.$2, size: 20, color: selected == item.$1 ? accent : theme.colorScheme.onSurface.withOpacity(0.55)), const SizedBox(width: 12), Text(item.$3, style: TextStyle(fontSize: 14, fontWeight: selected == item.$1 ? FontWeight.w600 : FontWeight.w400, color: selected == item.$1 ? accent : theme.colorScheme.onSurface.withOpacity(0.75)))]))))),
      const Spacer(),
      Padding(padding: const EdgeInsets.all(12), child: Text('AURA 2.0 • Media3', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.35)))),
    ]));
  }
}

// ---------------- Мини-плеер ----------------
class _MiniPlayer extends ConsumerWidget {
  final bool compact; final VoidCallback onOpenPlayer;
  const _MiniPlayer({required this.compact, required this.onOpenPlayer});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final t = player.current!;
    return Container(height: 76, decoration: BoxDecoration(color: theme.brightness == Brightness.dark ? Colors.black.withOpacity(0.55) : Colors.white.withOpacity(0.7), border: Border(top: BorderSide(color: theme.dividerColor))), child: Row(children: [
      const SizedBox(width: 12),
      GestureDetector(onTap: onOpenPlayer, child: CoverArt(track: t, size: 48, radius: 10)),
      const SizedBox(width: 12),
      Expanded(flex: compact ? 4 : 3, child: GestureDetector(onTap: onOpenPlayer, behavior: HitTestBehavior.opaque, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)), Text(t.artist.isEmpty ? 'AURA Player' : t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.55)))]))),
      Expanded(flex: compact ? 5 : 4, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: SeekBar(position: player.position, duration: player.duration, onSeek: player.seek, compact: true))),
      IconButton(tooltip: 'Предыдущий (P)', onPressed: player.prev, icon: const Icon(Icons.skip_previous_rounded)),
      _PlayButton(size: 44),
      IconButton(tooltip: 'Следующий (N)', onPressed: () => player.next(manual: true), icon: const Icon(Icons.skip_next_rounded)),
      if (!compact) Padding(padding: const EdgeInsets.only(left: 4, right: 12), child: Row(children: [IconButton(tooltip: 'Без звука (M)', onPressed: player.toggleMute, icon: Icon(player.muted || player.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded, size: 20)), SizedBox(width: 100, child: SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), overlayShape: const RoundSliderOverlayShape(overlayRadius: 10)), child: Slider(value: player.volume.clamp(0, 100), max: 100, onChanged: player.setVolume, activeColor: accent)))])),
    ]));
  }
}
class _PlayButton extends ConsumerWidget {
  final double size; const _PlayButton({required this.size});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(onTap: player.togglePlay, child: Container(width: size, height: size, decoration: BoxDecoration(color: accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: accent.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 3))]), child: Icon(player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.black, size: size * 0.6)));
  }
}

// ---------------- Мобильная навигация — 5 пунктов ----------------
class _MobileNav extends ConsumerWidget {
  final int selected;
  const _MobileNav({required this.selected});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const items = [(0, Icons.music_note_rounded, 'Музыка'), (1, Icons.movie_outlined, 'Видео'), (2, Icons.queue_music_outlined, 'Плейлисты'), (3, Icons.equalizer_rounded, 'Эквалайзер'), (4, Icons.settings_outlined, 'Настройки')];
    return Container(decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))), child: NavigationBar(height: 80, selectedIndex: selected, onDestinationSelected: (i) => ref.read(pageProvider.notifier).state = i, labelBehavior: NavigationDestinationLabelBehavior.alwaysShow, destinations: [for (final item in items) NavigationDestination(icon: Icon(item.$2), selectedIcon: Icon(item.$2, color: Theme.of(context).colorScheme.primary), label: item.$3)]));
  }
}
