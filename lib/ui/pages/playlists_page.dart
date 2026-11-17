import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../services/library.dart';
import '../../state/player_controller.dart';

class PlaylistsPage extends ConsumerStatefulWidget {
  const PlaylistsPage({super.key});

  @override
  ConsumerState<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends ConsumerState<PlaylistsPage> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(libraryProvider);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final wide = MediaQuery.of(context).size.width >= 980;

    final selected =
        lib.playlists.where((p) => p.id == _selectedId).firstOrNullSafe ??
            (lib.playlists.isNotEmpty ? lib.playlists.first : null);

    final tracks = selected == null ? <MediaTrack>[] : lib.tracksOfPlaylist(selected);

    final left = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
          child: Row(
            children: [
              Text('Плейлисты', style: theme.textTheme.titleMedium),
              const Spacer(),
              IconButton(
                tooltip: 'Новый плейлист',
                onPressed: () => _createPlaylist(),
                icon: Icon(Icons.add, color: accent),
              ),
            ],
          ),
        ),
        Expanded(
          child: lib.playlists.isEmpty
              ? Center(
                  child: Text(
                    'Создайте первый плейлист',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: lib.playlists.length,
                  itemBuilder: (context, i) {
                    final p = lib.playlists[i];
                    final isSel = selected?.id == p.id;
                    return ListTile(
                      selected: isSel,
                      leading: Icon(
                        Icons.queue_music_rounded,
                        color: isSel ? accent : null,
                      ),
                      title: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${p.paths.length} треков'),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 18),
                        onSelected: (v) {
                          if (v == 'rename') _renamePlaylist(p);
                          if (v == 'delete') {
                            ref.read(libraryProvider).deletePlaylist(p.id);
                            if (_selectedId == p.id) _selectedId = null;
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'rename', child: Text('Переименовать')),
                          PopupMenuItem(value: 'delete', child: Text('Удалить')),
                        ],
                      ),
                      onTap: () => setState(() => _selectedId = p.id),
                    );
                  },
                ),
        ),
      ],
    );

    final right = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selected?.name ?? 'Плейлист не выбран',
                  style: theme.textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selected != null && tracks.isNotEmpty) ...[
                IconButton(
                  tooltip: 'Добавить треки',
                  onPressed: () => _addTracks(selected.id),
                  icon: const Icon(Icons.playlist_add_rounded),
                ),
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(playerProvider).open(tracks, 0),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Играть всё'),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: selected == null
              ? Center(
                  child: Text(
                    'Выберите плейлист слева',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                )
              : tracks.isEmpty
                  ? Center(
                      child: Text(
                        'Пусто. Добавьте треки кнопкой выше.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: tracks.length,
                      onReorder: (from, to) => ref
                          .read(libraryProvider)
                          .reorderPlaylist(selected.id, from, to),
                      itemBuilder: (context, i) {
                        final t = tracks[i];
                        return ReorderableDragStartListener(
                          key: ValueKey(t.path + i.toString()),
                          index: i,
                          child: ListTile(
                            leading: Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: theme
                                    .colorScheme.onSurface
                                    .withOpacity(0.45),
                              ),
                            ),
                            title: Text(
                              t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              t.artist.isEmpty ? t.ext.toUpperCase() : t.artist,
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  fmtTime(
                                      Duration(milliseconds: t.durationMs)),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme
                                        .colorScheme.onSurface
                                        .withOpacity(0.5),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      size: 18),
                                  onPressed: () => ref
                                      .read(libraryProvider)
                                      .removeFromPlaylist(
                                          selected.id, t.path),
                                ),
                                const Icon(Icons.drag_handle_rounded,
                                    size: 16),
                              ],
                            ),
                            onTap: () =>
                                ref.read(playerProvider).open(tracks, i),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );

    if (!wide) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SizedBox(height: 240, child: Card(child: left)),
          const SizedBox(height: 12),
          SizedBox(height: 420, child: Card(child: right)),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 280, child: Card(child: left)),
        Expanded(child: right),
      ],
    );
  }

  Future<void> _createPlaylist() => _playlistNameDialog(
        title: 'Новый плейлист',
        onConfirm: (name) =>
            ref.read(libraryProvider).createPlaylist(name),
      );

  Future<void> _renamePlaylist(Playlist p) => _playlistNameDialog(
        title: 'Переименовать',
        initial: p.name,
        onConfirm: (name) =>
            ref.read(libraryProvider).renamePlaylist(p.id, name),
      );

  Future<void> _playlistNameDialog({
    required String title,
    String? initial,
    required ValueChanged<String> onConfirm,
  }) async {
    final controller = TextEditingController(text: initial ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
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
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) onConfirm(name);
    setState(() {});
  }

  Future<void> _addTracks(String playlistId) async {
    final lib = ref.read(libraryProvider);
    final all = [...lib.audio, ...lib.video];
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: const Text('Добавить треки'),
          content: SizedBox(
            width: 420,
            height: 380,
            child: all.isEmpty
                ? const Center(child: Text('Библиотека пуста'))
                : StatefulBuilder(
                    builder: (ctx2, setInner) {
                      final added = Set<String>.from(
                        lib.playlists
                            .where((p) => p.id == playlistId)
                            .map((p) => p.paths)
                            .expand((x) => x),
                      );
                      return ListView.builder(
                        itemCount: all.length,
                        itemBuilder: (context, i) {
                          final t = all[i];
                          final inPlaylist = added.contains(t.path);
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              inPlaylist
                                  ? Icons.check_circle_rounded
                                  : Icons.add_circle_outline_rounded,
                              color: inPlaylist
                                  ? theme.colorScheme.primary
                                  : null,
                              size: 20,
                            ),
                            title: Text(
                              t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              t.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              ref
                                  .read(libraryProvider)
                                  .addToPlaylist(playlistId, t);
                              setInner(() {});
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Готово'),
            ),
          ],
        );
      },
    );
    setState(() {});
  }
}

extension _FirstOrNullSafe<T> on Iterable<T> {
  T? get firstOrNullSafe => isEmpty ? null : first;
}
