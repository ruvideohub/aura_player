import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../services/library.dart';
import '../../services/native_bridge.dart';
import '../../services/settings.dart';
import '../../state/player_controller.dart';
import '../state/ui_state.dart';
import '../widgets/cover_art.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  bool _isVideo = false;
  String _query = '';
  String _sort = 'title';

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(libraryProvider);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final list = _filtered(lib);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Панель управления
          Row(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Аудио'), icon: Icon(Icons.music_note_rounded, size: 16)),
                  ButtonSegment(value: true, label: Text('Видео'), icon: Icon(Icons.movie_outlined, size: 16)),
                ],
                selected: {_isVideo},
                onSelectionChanged: (s) => setState(() => _isVideo = s.first),
                style: SegmentedButton.styleFrom(selectedForegroundColor: Colors.black),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Поиск по названию, исполнителю…',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButtonFormField<String>(
                value: _sort,
                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
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
                tooltip: 'Сканировать заново',
                onPressed: lib.scanning ? null : () => _scan(lib),
                icon: lib.scanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Счётчик
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${list.length} ${_plural(list.length)} · ${fmtSize(list.fold<int>(0, (s, t) => s + t.sizeBytes))}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.55),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(child: _buildList(lib, list, theme, accent)),
        ],
      ),
    );
  }

  String _plural(int n) {
    if (_isVideo) return n == 1 ? 'видео' : 'видео';
    final m10 = n % 10;
    final m100 = n % 100;
    if (m10 == 1 && m100 != 11) return 'трек';
    if (m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 > 20)) return 'трека';
    return 'треков';
  }

  List<MediaTrack> _filtered(LibraryController lib) {
    final source = _isVideo ? lib.video : lib.audio;
    final q = _query.trim().toLowerCase();
    var list = source;
    if (q.isNotEmpty) {
      list = list
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              t.artist.toLowerCase().contains(q) ||
              t.album.toLowerCase().contains(q))
          .toList();
    }
    final sorted = List.of(list);
    switch (_sort) {
      case 'title':
        sorted.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'artist':
        sorted.sort((a, b) {
          final av = a.artist.isEmpty ? 'яяя' : a.artist.toLowerCase();
          final bv = b.artist.isEmpty ? 'яяя' : b.artist.toLowerCase();
          return av.compareTo(bv);
        });
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

  Future<void> _scan(LibraryController lib) async {
    final messenger = ScaffoldMessenger.of(context);
    await lib.scan();
    final msg = lib.lastScanError != null
        ? 'Ошибка сканирования: ${lib.lastScanError}'
        : 'Добавлено ${lib.lastScanAdded} новых файлов';
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildList(
    LibraryController lib,
    List<MediaTrack> list,
    ThemeData theme,
    Color accent,
  ) {
    if (list.isEmpty) {
      final noDirs = !NativeBridge.isAndroid &&
          ref.read(settingsProvider).scanDirs.isEmpty;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isVideo
                  ? Icons.smart_display_outlined
                  : Icons.library_music_outlined,
              size: 64,
              color: accent,
            ),
            const SizedBox(height: 14),
            Text(
              'Здесь пока пусто',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              noDirs
                  ? 'Добавьте папки сканирования в настройках\nили перетащите файлы прямо в окно.'
                  : 'Отсканируйте папки или перетащите файлы в окно.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.55),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.read(pageProvider.notifier).state = 5,
              child: const Text('К настройкам'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor),
      itemBuilder: (context, i) {
        final t = list[i];
        final isCurrent =
            ref.watch(playerProvider.select((p) => p.current?.path)) == t.path;
        return ListTile(
          leading: _isVideo
              ? Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withOpacity(0.75),
                        accent.withOpacity(0.25),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.movie_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                )
              : CoverArt(track: t, size: 48, radius: 10),
          title: Text(
            t.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: isCurrent
                ? TextStyle(color: accent, fontWeight: FontWeight.w600)
                : null,
          ),
          subtitle: Text(
            _isVideo
                ? '${t.ext.toUpperCase()} · ${fmtSize(t.sizeBytes)} · ${fmtDate(t.addedAt)}'
                : [if (t.artist.isNotEmpty) t.artist, if (t.album.isNotEmpty) t.album]
                    .join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fmtTime(Duration(milliseconds: t.durationMs)),
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Действия',
                icon: const Icon(Icons.more_vert_rounded, size: 18),
                onSelected: (v) async {
                  if (v == 'play') {
                    await ref.read(playerProvider).open(list, i);
                  } else if (v == 'remove') {
                    lib.removeTrack(t);
                  } else if (v == 'playlist') {
                    _addToPlaylistDialog(t);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'play', child: Text('Воспроизвести')),
                  PopupMenuItem(value: 'playlist', child: Text('Добавить в плейлист')),
                  PopupMenuItem(value: 'remove', child: Text('Удалить из библиотеки')),
                ],
              ),
            ],
          ),
          onTap: () => ref.read(playerProvider).open(list, i),
        );
      },
    );
  }

  Future<void> _addToPlaylistDialog(MediaTrack t) async {
    final lib = ref.read(libraryProvider);
    if (lib.playlists.isEmpty) {
      final created = await _newPlaylistDialog();
      if (created != null) {
        lib.addToPlaylist(created, t);
      }
      return;
    }
    final id = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text('Выбрать плейлист', style: theme.textTheme.titleMedium),
              ),
              ...lib.playlists.map(
                (p) => ListTile(
                  leading: const Icon(Icons.queue_music_rounded),
                  title: Text(p.name),
                  subtitle: Text('${p.paths.length} треков'),
                  onTap: () => Navigator.pop(ctx, p.id),
                ),
              ),
              ListTile(
                leading: Icon(Icons.add, color: theme.colorScheme.primary),
                title: const Text('Новый плейлист'),
                onTap: () => Navigator.pop(ctx, '__new__'),
              ),
            ],
          ),
        );
      },
    );
    if (id == '__new__') {
      final created = await _newPlaylistDialog();
      if (created != null) lib.addToPlaylist(created, t);
    } else if (id != null) {
      lib.addToPlaylist(id, t);
    }
  }

  Future<String?> _newPlaylistDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый плейлист'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Название'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return null;
    final lib = ref.read(libraryProvider);
    lib.createPlaylist(name);
    return lib.playlists.last.id;
  }
}
