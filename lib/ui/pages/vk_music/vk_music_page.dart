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
import '../vk_site_auth_page.dart';

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

    // L1: Моя музыка требует PKCE-логина — показываем WebView на весь экран
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
          Expanded(child: VkSiteAuthPage(onSuccess: () => setState(() {}))),
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

class _LoginView extends ConsumerStatefulWidget {
  final VoidCallback onLogin;
  const _LoginView({required this.onLogin});
  @override
  ConsumerState<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<_LoginView> {
  final _login = TextEditingController();
  final _pass = TextEditingController();
  final _captcha = TextEditingController();
  final _code = TextEditingController();
  bool _loading = false;
  String? _captchaImg;
  String? _captchaSid;
  bool _needCode = false;

  @override
  void dispose() {
    _login.dispose();
    _pass.dispose();
    _captcha.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _doAuth() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(vkMusicApiProvider);
      await api.auth(
        _login.text.trim(),
        _pass.text,
        captchaSid: _captchaSid,
        captchaKey: _captcha.text.trim().isEmpty ? null : _captcha.text.trim(),
        code: _needCode ? _code.text.trim() : null,
      );
      widget.onLogin();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('VK авторизация OK')));
    } catch (e) {
      if (e is VkAuthException) {
        final p = e.payload;
        // captcha
        if (e.captchaImg != null) {
          setState(() {
            _captchaImg = e.captchaImg;
            _captchaSid = e.captchaSid;
          });
        }
        // need_validation / 2FA
        final needValidation = p['error'] == 'need_validation' || p['validation_type'] != null;
        if (needValidation) setState(() => _needCode = true);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.music_note_rounded, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            const Text('VK Музыка — вход', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Введи логин/пароль VK. Токен сохраняется локально.',
                textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
            const SizedBox(height: 16),
            TextField(controller: _login, decoration: const InputDecoration(labelText: 'Телефон / email', prefixIcon: Icon(Icons.person_outline))),
            const SizedBox(height: 8),
            TextField(controller: _pass, decoration: const InputDecoration(labelText: 'Пароль', prefixIcon: Icon(Icons.lock_outline)), obscureText: true),
            if (_captchaImg != null) ...[
              const SizedBox(height: 12),
              ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_captchaImg!, height: 50, errorBuilder: (_,__,___)=> const Icon(Icons.image_not_supported))),
              const SizedBox(height: 8),
              TextField(controller: _captcha, decoration: const InputDecoration(labelText: 'Код с картинки (капча)', prefixIcon: Icon(Icons.image_outlined))),
            ],
            if (_needCode) ...[
              const SizedBox(height: 12),
              TextField(controller: _code, decoration: const InputDecoration(labelText: 'Код 2FA / SMS', prefixIcon: Icon(Icons.sms_outlined))),
            ],
            const SizedBox(height: 16),
            _loading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: FilledButton(onPressed: _doAuth, child: const Text('Войти')),
                  ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                final c = TextEditingController();
                final token = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Вставить токен вручную'),
                    content: TextField(controller: c, decoration: const InputDecoration(hintText: 'access_token')),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')), FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Сохранить'))],
                  ),
                );
                if (token != null && token.isNotEmpty) {
                  final sp = ref.read(sharedPrefsProvider);
                  await VkTokenStorage(sp).save(token, 0);
                  widget.onLogin();
                }
              },
              child: const Text('Вставить токен вручную'),
            ),
          ]),
        ),
      ),
    );
  }
}
