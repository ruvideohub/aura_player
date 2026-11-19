import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../services/vk_music/vk_music_api.dart';
import '../../../services/vk_music/vk_token_storage.dart';
import '../../../services/library.dart';
import '../../../services/settings.dart';
import '../../../models/models.dart';
import '../../../state/player_controller.dart';
import 'vk_webview_page.dart';
import 'vk_id_auth_page.dart';
import '../vk_auth_page.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('sharedPrefsProvider not overridden in main'));

final vkMusicApiProvider = Provider<VkMusicApi>((ref) {
  throw UnimplementedError('vkMusicApiProvider not overridden in main');
});

class VkMusicPage extends ConsumerStatefulWidget {
  const VkMusicPage({super.key});
  @override
  ConsumerState<VkMusicPage> createState() => _VkMusicPageState();
}

enum _VkTab { my, popular, search }

class _VkMusicPageState extends ConsumerState<VkMusicPage> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<VkTrack> _tracks = [];
  bool _loading = false;
  String _query = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    // грузим после первого кадра чтобы ref готов
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMy());
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadMy() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(vkMusicApiProvider);
      _tracks = await api.getMyAudio();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPopular() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(vkMusicApiProvider);
      _tracks = await api.getPopular();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(vkMusicApiProvider);
      _tracks = await api.search(q);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  MediaTrack _toMedia(VkTrack t) => MediaTrack(
        path: t.url!,
        isVideo: false,
        title: t.title,
        artist: t.artist,
        album: '',
        durationMs: t.duration * 1000,
        sizeBytes: 0,
        addedAt: DateTime.now().millisecondsSinceEpoch,
      );

  Future<void> _play(VkTrack t) async {
    if (t.url == null || t.url!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ссылка пустая — возможно трек без URL (требует обновления токена)')));
      return;
    }
    // Собираем всю видимую очередь — чтобы плеер шёл дальше, а не стопорился на 1 треке
    final playable = _tracks.where((e) => e.url != null && e.url!.isNotEmpty).toList();
    if (playable.isEmpty) return;
    final queue = playable.map(_toMedia).toList();
    var start = playable.indexWhere((e) => e.url == t.url);
    if (start < 0) start = 0;

    final ctrl = ref.read(playerProvider.notifier);
    // VK-плейлист должен идти по кругу по умолчанию (как в VK) — если off, ставим all
    if (ctrl.repeat == RepeatMode.off) {
      ctrl.repeat = RepeatMode.all;
    }
    await ctrl.open(queue, start);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('▶ ${t.artist} — ${t.title} • ${playable.length} треков в очереди')));
  }

  Future<void> _playAll({bool shuffle = false}) async {
    final playable = _tracks.where((e) => e.url != null && e.url!.isNotEmpty).toList();
    if (playable.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нет треков с URL для воспроизведения')));
      return;
    }
    final queue = playable.map(_toMedia).toList();
    final ctrl = ref.read(playerProvider.notifier);
    ctrl.repeat = RepeatMode.all;
    if (shuffle && !ctrl.shuffle) ctrl.toggleShuffle();
    if (!shuffle && ctrl.shuffle) ctrl.toggleShuffle();
    await ctrl.open(queue, 0);
  }

  Future<void> _shufflePlay() => _playAll(shuffle: true);

  Future<void> _download(VkTrack t) async {
    if (t.url == null || t.url!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нет ссылки для скачивания')));
      return;
    }
    try {
      // Android: Downloads/AURA, иначе Documents/AURA
      Directory? base;
      try {
        if (Platform.isAndroid) {
          base = await getDownloadsDirectory();
          base ??= await getApplicationDocumentsDirectory();
        } else {
          base = await getApplicationDocumentsDirectory();
        }
      } catch (_) {
        base = await getApplicationDocumentsDirectory();
      }
      final safeName = '${t.artist} - ${t.title}.mp3'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${base!.path}/AURA/$safeName');
      await file.parent.create(recursive: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Качаю ${t.title}...')));
      final resp = await http.get(Uri.parse(t.url!));
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      await file.writeAsBytes(resp.bodyBytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Сохранено: ${file.path}'), duration: const Duration(seconds: 4)));
      // добавляем в офлайн библиотеку чтобы сразу появился в списке
      try {
        final media = MediaTrack.fromFile(file, isVideo: false);
        ref.read(libraryProvider).importTracks([media]);
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка скачивания: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(sharedPrefsProvider);
    final storage = VkTokenStorage(prefs);
    final isAuth = storage.isAuthorized;
    final theme = Theme.of(context);

    // Успешный способ — ИД ВК Музыка (телефон→код→пароль→silent_token→moosic), как в архиве 70c76b93
    if (!isAuth && _tab.index == 0) {
      return Column(
        children: [
          TabBar(
            controller: _tab,
            onTap: (i) {
              if (i == 0) _loadMy();
              if (i == 1) _loadPopular();
            },
            tabs: const [Tab(text: 'Моя'), Tab(text: 'Популярное'), Tab(text: 'Поиск')],
          ),
          Expanded(child: VkIdAuthPage(onSuccess: () => setState(() {}))),
        ],
      );
    }

    return Column(children: [
      TabBar(
        controller: _tab,
        onTap: (i) {
          if (i == 0) _loadMy();
          if (i == 1) _loadPopular();
        },
        tabs: const [Tab(text: 'Моя'), Tab(text: 'Популярное'), Tab(text: 'Поиск')],
      ),
      if (!isAuth)
        Material(
          color: theme.colorScheme.primaryContainer,
          child: InkWell(
            onTap: () => setState(() => _tab.index = 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(children: [
                Icon(Icons.info_outline, size: 16, color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(child: Text('Войдите в VK ID для избранного • Поиск работает без логина', style: TextStyle(fontSize: 12, color: theme.colorScheme.onPrimaryContainer))),
                Text('Войти', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
              ]),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(hintText: 'Поиск…', prefixIcon: Icon(Icons.search, size: 18), isDense: true),
              onSubmitted: _search,
              onChanged: (v) => _query = v,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.search), tooltip: 'Искать', onPressed: () => _search(_query)),
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Обновить', onPressed: () {
            final idx = _tab.index;
            if (idx == 0) _loadMy();
            if (idx == 1) _loadPopular();
            if (idx == 2) _search(_query);
          }),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Выйти',
            onPressed: () async {
              await storage.clear();
              if (mounted) setState(() {});
            },
          ),
        ]),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
        ),
      if (_tracks.isNotEmpty && !_loading)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text('Играть всё (${_tracks.length})', style: const TextStyle(fontSize: 13)),
                onPressed: _playAll,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.shuffle_rounded, size: 18),
                label: const Text('Перемешать', style: TextStyle(fontSize: 13)),
                onPressed: _shufflePlay,
              ),
            ),
          ]),
        ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _tracks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.music_note_rounded, size: 48, color: theme.colorScheme.primary),
                        const SizedBox(height: 12),
                        Text('Треков нет', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text('Попробуй Поиск или обнови Мою музыку', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                      ]),
                    ),
                  )
                : ListView.builder(
                    cacheExtent: 800,
                    itemCount: _tracks.length,
                    itemBuilder: (_, i) {
                      final t = _tracks[i];
                      return ListTile(
                        leading: t.cover != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(t.cover!, width: 48, height: 48, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.music_note)),
                              )
                            : const Icon(Icons.music_note),
                        title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${t.artist} • ${t.duration ~/ 60}:${(t.duration % 60).toString().padLeft(2, '0')}', maxLines: 1, style: const TextStyle(fontSize: 12)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.play_arrow_rounded), tooltip: 'Играть', onPressed: () => _play(t)),
                          IconButton(icon: const Icon(Icons.download_rounded), tooltip: 'Скачать в офлайн', onPressed: () => _download(t)),
                        ]),
                        onTap: () => _play(t),
                      );
                    },
                  ),
      ),
    ]);
  }
}

/// Ручной вход VK ID как в успешном архиве: браузер → blank.html → вставка ссылки
class _ManualVkLogin extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const _ManualVkLogin({required this.onSuccess});
  @override
  ConsumerState<_ManualVkLogin> createState() => _ManualVkLoginState();
}

class _ManualVkLoginState extends ConsumerState<_ManualVkLogin> {
  final _ctrl = TextEditingController();
  bool _alt = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Icon(Icons.music_note_rounded, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 12),
        const Text('VK Музыка — вход', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Откроется сайт VK — войди телефон → код → пароль, нажми Разрешить, скопируй ссылку из адресной строки и вставь сюда.\nЭто чистый implicit flow без баноопасных хаков.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => VkWebViewHelper.openBrowser(alt: _alt),
          icon: const Icon(Icons.open_in_browser_rounded),
          label: Text(_alt ? 'Открыть VK (6121396)' : 'Открыть сайт VK (6287487) ✓'),
        ),
        TextButton(onPressed: () => setState(() => _alt = !_alt), child: Text(_alt ? 'На 6287487' : 'Попробовать 6121396')),
        const Divider(),
        TextField(
          controller: _ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Вставь ссылку blank.html',
            hintText: 'https://oauth.vk.com/blank.html#access_token=...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: () async {
            final token = VkWebViewHelper.extractTokenFromUrl(_ctrl.text);
            final uid = VkWebViewHelper.extractUserIdFromUrl(_ctrl.text) ?? 0;
            if (token == null || token.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не нашёл access_token в ссылке')));
              return;
            }
            final prefs = ref.read(sharedPrefsProvider);
            await VkTokenStorage(prefs).save(token, uid);
            await prefs.setString('vk_music_token', token);
            if (uid != 0) await prefs.setInt('vk_music_uid', uid);
            widget.onSuccess();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('VK токен сохранён')));
          },
          child: const Text('Сохранить'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Авто VK ID')), body: VkAuthPage(onSuccess: () { Navigator.of(context).pop(); widget.onSuccess(); })))),
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Попробовать авто WebView (PKCE)'),
        ),
      ]),
    );
  }
}

