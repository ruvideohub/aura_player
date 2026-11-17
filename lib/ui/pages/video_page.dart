import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../services/library.dart';
import '../../state/player_controller.dart';
import '../state/ui_state.dart';
import '../widgets/cover_art.dart';
import '../widgets/seekbar.dart';
import '../widgets/player_gesture_overlay.dart';
import '../widgets/video_thumb.dart';

bool get _isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

class VideoPage extends ConsumerStatefulWidget {
  const VideoPage({super.key});
  @override
  ConsumerState<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends ConsumerState<VideoPage> {
  bool _controlsVisible = true;
  Timer? _hideTimer;
  double? _brightnessOverlay; // 0..1 для подсказки
  double? _volumeOverlay;
  Timer? _overlayTimer;
  double _startBrightness = 0.5;
  double _startVolume = 0.5;
  double _fakeBrightness = 1.0;
  String _query = '';
  String _sort = 'date';
  // Для различения свайпа: горизонтальный = перемотка, вертикальный = яркость/громкость
  Offset? _panStart;
  bool? _isHorizontalPan;

  @override
  void dispose() { _hideTimer?.cancel(); _overlayTimer?.cancel(); super.dispose(); }

  void _showOverlay({double? brightness, double? volume}) {
    setState(() {
      if (brightness != null) _brightnessOverlay = brightness;
      if (volume != null) _volumeOverlay = volume;
    });
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() { _brightnessOverlay = null; _volumeOverlay = null; });
    });
  }

  void _scheduleHide(PlayerController player) {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && ref.read(playerProvider).isPlaying && _controlsVisible) setState(() => _controlsVisible = false);
    });
  }
  void _showControls(PlayerController player) {
    _hideTimer?.cancel();
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide(player);
  }
  void _toggleControls(PlayerController player) {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls(player);
    }
  }

  Future<void> _toggleFullscreen() async {
    final fs = !ref.read(fullscreenProvider);
    ref.read(fullscreenProvider.notifier).state = fs;
    if (_isDesktop) {
      try { await windowManager.setFullScreen(fs); } catch (_) {}
    } else {
      // Android/iOS — иммерсивный фуллскрин
      try {
        if (fs) {
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
          await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
        } else {
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
        }
      } catch (_) {}
    }
  }

  Future<void> _openVideo() async {
    const typeGroup = XTypeGroup(label: 'Видео', extensions: [...videoExtensions, ...streamExtensions]);
    try {
      final files = await openFiles(acceptedTypeGroups: [typeGroup]);
      if (files.isEmpty) return;
      final tracks = files.map((f) => MediaTrack.fromFile(File(f.path), isVideo: true)).toList();
      ref.read(libraryProvider).importTracks(tracks);
      await ref.read(playerProvider).open(tracks, 0);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _openStream() async {
    final ctrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Открыть поток'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Поддерживает HLS (.m3u8), DASH (.mpd), fMP4 (.m4s), RTMP/RTSP', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'https://example.com/stream.m3u8', prefixIcon: Icon(Icons.link_rounded)), onSubmitted: (v) => Navigator.pop(ctx, v)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Открыть')),
        ],
      ),
    );
    if (url == null || url.trim().isEmpty) return;
    final u = url.trim();
    if (!isStreamUrl(u) && !streamExtensions.contains(extOf(u)) && !u.contains('.m3u8') && !u.contains('.mpd')) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Вставь http(s) ссылку на поток')));
      return;
    }
    final track = MediaTrack.fromUrl(u, isVideo: true);
    ref.read(libraryProvider).importTracks([track]);
    await ref.read(playerProvider).open([track], 0);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Открываю: ${track.title}')));
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(playerProvider.select((p) => p.current));
    final hasVideo = ref.watch(playerProvider.select((p) => p.hasVideo));
    final player = ref.read(playerProvider);
    ref.listen(playerProvider.select((p) => p.current?.path), (prev, next) {
      if (next != null && hasVideo) _showControls(player);
    });
    ref.listen(playerProvider.select((p) => p.isPlaying), (prev, playing) {
      if (playing == true) _scheduleHide(player);
    });
    if (current != null && hasVideo) {
      return _videoPlayer(context, player, current);
    }
    return _videoLibrary(context, player);
  }

  Widget _videoPlayer(BuildContext context, PlayerController player, MediaTrack current) {
    final fit = ref.watch(videoFitProvider);
    return ColoredBox(
      color: Colors.black,
      child: Stack(fit: StackFit.expand, children: [
        Positioned.fill(child: RepaintBoundary(child: ColoredBox(color: Colors.black, child: player.buildVideoView(fit: fit)))),
        // Твой Compose-оверлей — без белого, жесты под панелями
        Positioned.fill(
          child: PlayerGestureOverlay(
            player: player,
            onTap: () => _toggleControls(player),
            onDoubleTapLeft: () { player.seek(player.position - const Duration(seconds: 10)); _showControls(player); },
            onDoubleTapRight: () { player.seek(player.position + const Duration(seconds: 10)); _showControls(player); },
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        StreamBuilder<bool>(stream: player.bufferingStream, builder: (context, snap) {
          if (snap.data != true) return const SizedBox.shrink();
          return const Center(child: SizedBox(width: 44, height: 44, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)));
        }),
        // Контролы — только top и bottom, центр свободен
        Positioned(
          top: 0, left: 0, right: 0,
          child: IgnorePointer(
            ignoring: !_controlsVisible,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => _toggleControls(player), child: _topBar(context, player, current)),
            ),
          ),
        ),
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: IgnorePointer(
            ignoring: !_controlsVisible,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('Свайп внизу — перемотка • слева яркость, справа громкость • дабл-тап края ±10с', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10), textAlign: TextAlign.center)),
                if (ref.watch(fullscreenProvider))
                  Padding(padding: const EdgeInsets.only(bottom: 6), child: Center(child: FilledButton.icon(onPressed: _toggleFullscreen, icon: const Icon(Icons.fullscreen_exit_rounded, size: 18), label: const Text('Выйти из полного экрана', style: TextStyle(fontSize: 13)), style: FilledButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8))))),
                GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => _toggleControls(player), child: _bottomBar(context, player)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _gestureOverlay(IconData icon, String value, String label) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)), Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))])]));
  }

  Widget _videoLibrary(BuildContext context, PlayerController player) {
    final lib = ref.watch(libraryProvider);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final list = _filtered(lib);

    if (lib.video.isEmpty && list.isEmpty && _query.isEmpty) {
      return Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [theme.colorScheme.surface, accent.withOpacity(0.06)])),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.smart_display_outlined, size: 72, color: accent),
          const SizedBox(height: 16),
          Text('Нет видео', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Отсканируй папки или открой файл вручную.', textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
          const SizedBox(height: 20),
          Wrap(spacing: 12, alignment: WrapAlignment.center, children: [
            FilledButton.icon(onPressed: _openVideo, icon: const Icon(Icons.folder_open_rounded), label: const Text('Открыть видео')),
            FilledButton.icon(onPressed: _openStream, icon: const Icon(Icons.stream_rounded), label: const Text('Открыть поток'), style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.secondary)),
            OutlinedButton.icon(onPressed: () async { final m = ScaffoldMessenger.of(context); await lib.scan(); m.showSnackBar(SnackBar(content: Text(lib.lastScanError != null ? 'Ошибка: ${lib.lastScanError}' : 'Добавлено ${lib.lastScanAdded}'))); }, icon: lib.scanning ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded), label: Text(lib.scanning ? 'Сканирую...' : 'Сканировать')),
            TextButton(onPressed: () => ref.read(pageProvider.notifier).state = 4, child: const Text('Настройки')),
          ]),
        ])),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: TextField(onChanged: (v) => setState(() => _query = v), decoration: const InputDecoration(hintText: 'Поиск видео…', prefixIcon: Icon(Icons.search, size: 18), isDense: true))),
          const SizedBox(width: 12),
          DropdownButton<String>(value: _sort, underline: const SizedBox.shrink(), borderRadius: BorderRadius.circular(12), items: const [DropdownMenuItem(value: 'date', child: Text('По дате')), DropdownMenuItem(value: 'title', child: Text('По названию')), DropdownMenuItem(value: 'duration', child: Text('По длительности'))], onChanged: (v) => setState(() => _sort = v ?? 'date')),
          const SizedBox(width: 8),
          IconButton(tooltip: 'Открыть файлы', onPressed: _openVideo, icon: const Icon(Icons.add_rounded)),
          IconButton(tooltip: 'Открыть поток (HLS/DASH/fMP4)', onPressed: _openStream, icon: const Icon(Icons.stream_rounded)),
          IconButton(tooltip: 'Сканировать', onPressed: lib.scanning ? null : () async { final m = ScaffoldMessenger.of(context); await lib.scan(); m.showSnackBar(SnackBar(content: Text(lib.lastScanError != null ? 'Ошибка: ${lib.lastScanError}' : 'Добавлено ${lib.lastScanAdded}'))); }, icon: lib.scanning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded)),
        ]),
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('${list.length} видео · ${fmtSize(list.fold<int>(0, (s, t) => s + t.sizeBytes))}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.55)))),
        const SizedBox(height: 4),
        Expanded(child: list.isEmpty ? Center(child: Text('Ничего не найдено', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)))) : GridView.builder(cacheExtent: 600, addAutomaticKeepAlives: false, addRepaintBoundaries: true, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : (MediaQuery.of(context).size.width > 600 ? 2 : 1), childAspectRatio: 1.55, mainAxisSpacing: 12, crossAxisSpacing: 12), itemCount: list.length, itemBuilder: (context, i) {
          final t = list[i];
          return RepaintBoundary(child: Card(clipBehavior: Clip.antiAlias, child: InkWell(onTap: () => ref.read(playerProvider).open(list, i), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: Stack(children: [
              Positioned.fill(child: VideoThumb(path: t.path)),
              Center(child: Icon(Icons.play_circle_fill_rounded, size: 48, color: Colors.white.withOpacity(0.95))),
              Positioned(bottom: 6, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)), child: Text(fmtTime(Duration(milliseconds: t.durationMs)), style: const TextStyle(color: Colors.white, fontSize: 11)))),
              Positioned(top: 6, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)), child: Text(t.ext.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)))),
            ])),
            Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), child: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 10), child: Row(children: [Expanded(child: Text(fmtSize(t.sizeBytes), style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.5)), maxLines: 1, overflow: TextOverflow.ellipsis)), PopupMenuButton<String>(onSelected: (v) async { if (v == 'play') await ref.read(playerProvider).open(list, i); if (v == 'remove') lib.removeTrack(t); }, itemBuilder: (_) => const [PopupMenuItem(value: 'play', child: Text('Воспроизвести')), PopupMenuItem(value: 'remove', child: Text('Удалить'))])])),
          ]))));
        })),
      ]),
    );
  }

  List<MediaTrack> _filtered(LibraryController lib) {
    final q = _query.trim().toLowerCase();
    var list = lib.video;
    if (q.isNotEmpty) list = list.where((t) => t.title.toLowerCase().contains(q)).toList();
    final sorted = List.of(list);
    switch (_sort) { case 'title': sorted.sort((a,b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())); break; case 'date': sorted.sort((a,b) => b.addedAt.compareTo(a.addedAt)); break; case 'duration': sorted.sort((a,b) => b.durationMs.compareTo(a.durationMs)); break; }
    return sorted;
  }

  void _cycleFit() {
    final cur = ref.read(videoFitProvider);
    final next = VideoFit.values[(cur.index + 1) % VideoFit.values.length];
    ref.read(videoFitProvider.notifier).state = next;
  }

  Widget _fitMenu(BuildContext context) {
    final fit = ref.watch(videoFitProvider);
    return PopupMenuButton<VideoFit>(
      tooltip: 'Масштаб: ${fit.label}',
      icon: Stack(alignment: Alignment.center, children: [
        const Icon(Icons.aspect_ratio_rounded, color: Colors.white, size: 22),
        Positioned(bottom: 0, child: Container(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3)), child: Text(fit.shortLabel, style: const TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: Colors.black)))),
      ]),
      onSelected: (v) => ref.read(videoFitProvider.notifier).state = v,
      itemBuilder: (_) => [for (final f in VideoFit.values) PopupMenuItem(value: f, child: Row(children: [Icon(fit == f ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), Text('${f.label} (${f.shortLabel})')]))],
    );
  }

  Widget _topBar(BuildContext context, PlayerController player, MediaTrack t) {
    final isAndroid = player.isAndroid;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.65), Colors.transparent])), child: Row(children: [
      IconButton(tooltip: 'Закрыть', icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () async {
        // выход из фуллскрина + остановка
        if (ref.read(fullscreenProvider)) {
          ref.read(fullscreenProvider.notifier).state = false;
          if (_isDesktop) {
            try { await windowManager.setFullScreen(false); } catch (_) {}
          } else {
            try {
              await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
              await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
            } catch (_) {}
          }
        }
        await player.stopAndClearCurrent();
        if (mounted) _hideTimer?.cancel();
      }),
      Expanded(child: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white))),
      _fitMenu(context),
      _speedMenu(context, player),
      if (!isAndroid) ...[IconButton(tooltip: 'Аудиодорожка', icon: const Icon(Icons.audiotrack_rounded, color: Colors.white), onPressed: () => _audioTrackMenu(context, player)), IconButton(tooltip: 'Субтитры', icon: const Icon(Icons.subtitles_outlined, color: Colors.white), onPressed: () => _subtitleMenu(context, player))] else Tooltip(message: 'Дорожки/субтитры — позже', child: IconButton(icon: const Icon(Icons.subtitles_outlined, color: Colors.white38), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Дорожки скоро на Media3'))))),
    ]));
  }

  Widget _speedMenu(BuildContext context, PlayerController player) {
    const speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    return PopupMenuButton<double>(tooltip: 'Скорость', icon: const Icon(Icons.speed_rounded, color: Colors.white), onSelected: player.setRate, itemBuilder: (_) => [for (final s in speeds) PopupMenuItem(value: s, child: Row(children: [if (player.rate == s) Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.primary) else const SizedBox(width: 16), const SizedBox(width: 8), Text('${s.toStringAsFixed(2)}x')]))]);
  }

  Future<void> _audioTrackMenu(BuildContext context, PlayerController player) async {
    final tracks = player.audioTracks; if (tracks.isEmpty) return; final selectedId = player.selectedAudioTrackId; final chosen = await showMenu<AudioTrack>(context: context, position: const RelativeRect.fromLTRB(200, 60, 40, 300), items: [for (var i=0;i<tracks.length;i++) PopupMenuItem(value: tracks[i], child: Row(children: [Icon(selectedId==tracks[i].id?Icons.radio_button_checked:Icons.radio_button_off, size:16, color: Theme.of(context).colorScheme.primary), const SizedBox(width:8), Expanded(child: Text(tracks[i].title?.isNotEmpty==true?tracks[i].title!:(tracks[i].language?.isNotEmpty==true?tracks[i].language!:'Дорожка ${i+1}'), overflow: TextOverflow.ellipsis))]))]);
    if (chosen!=null) await player.selectAudioTrack(chosen);
  }
  Future<void> _subtitleMenu(BuildContext context, PlayerController player) async {
    final tracks = player.subtitleTracks; final selectedId = player.selectedSubtitleTrackId; final theme = Theme.of(context); final chosen = await showMenu<Object>(context: context, position: const RelativeRect.fromLTRB(240, 60, 20, 300), items: [const PopupMenuItem(value:'off', child: Text('Выключены')), const PopupMenuItem(value:'external', child: Text('Загрузить файл…')), for (final t in tracks) PopupMenuItem(value:t, child: Row(children:[Icon(selectedId==t.id&&t.id!='no'&&t.id!='auto'?Icons.radio_button_checked:Icons.radio_button_off, size:16, color:theme.colorScheme.primary), const SizedBox(width:8), Expanded(child: Text(t.title?.isNotEmpty==true?t.title!:(t.language?.isNotEmpty==true?t.language!:'Дорожка'), overflow: TextOverflow.ellipsis))]))]);
    if (chosen is String && chosen=='off') await player.selectSubtitleOff(); else if (chosen is String && chosen=='external') { const typeGroup = XTypeGroup(label:'Субтитры', extensions:['srt','ass','ssa','vtt']); try { final file = await openFile(acceptedTypeGroups:[typeGroup]); if (file!=null) await player.loadExternalSubtitle(file.path); } catch(_){} } else if (chosen is SubtitleTrack) await player.selectSubtitleTrack(chosen);
  }

  Widget _bottomBar(BuildContext context, PlayerController player) {
    final theme = Theme.of(context);
    final isPlaying = ref.watch(playerProvider.select((p) => p.isPlaying));
    final muted = ref.watch(playerProvider.select((p) => p.muted));
    final volume = ref.watch(playerProvider.select((p) => p.volume));
    return Container(padding: const EdgeInsets.fromLTRB(16, 4, 16, 10), color: Colors.black.withOpacity(0.55), child: Column(children: [
      const LiveSeekBar(compact: true), const SizedBox(height:2),
      Row(children: [
        IconButton(tooltip:'Предыдущий', onPressed: player.prev, icon: const Icon(Icons.skip_previous_rounded, color: Colors.white)),
        GestureDetector(onTap: player.togglePlay, child: Container(width:52, height:52, decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle), child: Icon(isPlaying?Icons.pause_rounded:Icons.play_arrow_rounded, color: Colors.black, size:30))),
        IconButton(tooltip:'Следующий', onPressed: ()=>player.next(manual:true), icon: const Icon(Icons.skip_next_rounded, color: Colors.white)),
        const SizedBox(width:4),
        IconButton(tooltip:'Без звука', onPressed: player.toggleMute, icon: Icon(muted||volume==0?Icons.volume_off_rounded:Icons.volume_up_rounded, color: Colors.white, size:20)),
        SizedBox(width:110, child: _VideoVolumeSlider(volume: volume, player: player)),
        const Spacer(),
        IconButton(tooltip:'Полный экран', onPressed: _toggleFullscreen, icon: Icon(ref.watch(fullscreenProvider)?Icons.fullscreen_exit_rounded:Icons.fullscreen_rounded, color: Colors.white)),
      ]),
    ]));
  }

}

class _VideoVolumeSlider extends StatelessWidget {
  final double volume; final PlayerController player;
  const _VideoVolumeSlider({required this.volume, required this.player});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliderTheme(data: const SliderThemeData(trackHeight:3, thumbShape: RoundSliderThumbShape(enabledThumbRadius:6), overlayShape: RoundSliderOverlayShape(overlayRadius:10)), child: Slider(value: volume.clamp(0,100), max:100, onChanged: player.setVolume, activeColor: theme.colorScheme.primary, inactiveColor: Colors.white24));
  }
}
