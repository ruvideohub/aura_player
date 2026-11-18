import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../services/vk_music/vk_music_api.dart';
import '../../../services/vk_music/vk_token_storage.dart';
import '../../../services/library.dart';
import '../../../state/player_controller.dart';
import '../../../models/models.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

final vkMusicApiProvider = Provider<VkMusicApi>((ref) {
  throw UnimplementedError('override in main');
});

class VkMusicPage extends ConsumerStatefulWidget {
  const VkMusicPage({super.key});
  @override ConsumerState<VkMusicPage> createState() => _VkMusicPageState();
}

class _VkMusicPageState extends ConsumerState<VkMusicPage> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<VkTrack> _tracks = [];
  bool _loading = false;
  String _query = '';

  @override void initState() { super.initState(); _tab = TabController(length: 3, vsync: this); _loadMy(); }
  @override void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _loadMy() async {
    setState(() => _loading = true);
    try { final api = ref.read(vkMusicApiProvider); _tracks = await api.getMyAudio(); } catch (_) {} finally { if(mounted) setState(()=> _loading=false); }
  }
  Future<void> _loadPopular() async {
    setState(() => _loading = true);
    try { final api = ref.read(vkMusicApiProvider); _tracks = await api.getPopular(); } catch (_) {} finally { if(mounted) setState(()=> _loading=false); }
  }
  Future<void> _search(String q) async {
    if(q.trim().isEmpty) return;
    setState(() => _loading = true);
    try { final api = ref.read(vkMusicApiProvider); _tracks = await api.search(q); } catch (_) {} finally { if(mounted) setState(()=> _loading=false); }
  }

  Future<void> _play(VkTrack t) async {
    if(t.url == null || t.url!.isEmpty){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ссылка протухла, обнови каталог'))); return; }
    final track = MediaTrack(
      path: t.url!, title: t.title, artist: t.artist, album: '',
      durationMs: t.duration*1000, sizeBytes: 0, ext: 'mp3', isVideo: false, addedAt: DateTime.now(),
      // используем url как path, isVideo false → пойдет через Android backend
    );
    await ref.read(playerController.notifier).open([track], 0);
  }

  Future<void> _download(VkTrack t) async {
    if(t.url == null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/AURA/${t.artist} - ${t.title}.mp3'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_'));
      await file.parent.create(recursive: true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Качаю ${t.title}...')));
      final resp = await http.get(Uri.parse(t.url!));
      await file.writeAsBytes(resp.bodyBytes);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Сохранено: ${file.path}')));
      // добавляем в офлайн библиотеку
      // await ref.read(libraryProvider).scan(); // можно дернуть скан
    } catch(e){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'))); }
  }

  @override Widget build(BuildContext context) {
    final storage = VkTokenStorage(ref.read(sharedPrefsProvider));
    if(!storage.isAuthorized) return _LoginView(onLogin: ()=> setState((){}));
    return Column(children: [
      TabBar(controller: _tab, onTap: (i){ if(i==0) _loadMy(); if(i==1) _loadPopular(); }, tabs: const [Tab(text:'Моя'), Tab(text:'Популярное'), Tab(text:'Поиск')]),
      Padding(padding: const EdgeInsets.all(8), child: Row(children:[
        Expanded(child: TextField(decoration: const InputDecoration(hintText:'Поиск...', prefixIcon: Icon(Icons.search)), onSubmitted: _search, onChanged: (v)=> _query=v)),
        IconButton(icon: const Icon(Icons.search), onPressed: ()=> _search(_query)),
        IconButton(icon: const Icon(Icons.logout), onPressed: () async { await storage.clear(); setState((){}); }),
      ])),
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(itemCount: _tracks.length, itemBuilder: (_,i){
        final t = _tracks[i];
        return ListTile(
          leading: t.cover!=null ? Image.network(t.cover!, width:48, height:48, errorBuilder: (_,__,___)=> const Icon(Icons.music_note)) : const Icon(Icons.music_note),
          title: Text(t.title, maxLines:1, overflow: TextOverflow.ellipsis),
          subtitle: Text(t.artist, maxLines:1),
          trailing: Row(mainAxisSize: MainAxisSize.min, children:[
            IconButton(icon: const Icon(Icons.play_arrow), onPressed: ()=> _play(t)),
            IconButton(icon: const Icon(Icons.download), onPressed: ()=> _download(t)),
          ]),
          onTap: ()=> _play(t),
        );
      })),
    ]);
  }
}

class _LoginView extends StatefulWidget {
  final VoidCallback onLogin;
  const _LoginView({required this.onLogin});
  @override State<_LoginView> createState()=> _LoginViewState();
}
class _LoginViewState extends State<_LoginView> {
  final _login = TextEditingController();
  final _pass = TextEditingController();
  bool _loading=false;
  String? _captchaImg; String? _captchaSid; String? _code;
  @override Widget build(BuildContext context){
    return Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[
      const Icon(Icons.music_note, size:64), const SizedBox(height:16),
      const Text('VK Музыка — вход', style: TextStyle(fontSize:18, fontWeight: FontWeight.bold)),
      const SizedBox(height:8),
      TextField(controller: _login, decoration: const InputDecoration(labelText:'Телефон / email')),
      TextField(controller: _pass, decoration: const InputDecoration(labelText:'Пароль'), obscureText:true),
      if(_captchaImg!=null) ...[const SizedBox(height:12), Image.network(_captchaImg!), TextField(decoration: const InputDecoration(labelText:'Капча'), onChanged:(v)=> _captchaSid=v)],
      if(_code!=null) TextField(decoration: const InputDecoration(labelText:'Код 2FA'), onChanged:(v)=> _code=v),
      const SizedBox(height:16),
      _loading ? const CircularProgressIndicator() : FilledButton(onPressed: () async {
        setState(()=> _loading=true);
        try {
          // TODO: получить storage/api via ProviderScope override
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Логин в разработке — добавь токен вручную в настройках')));
        } catch(e){
          if(e is VkAuthException && e.captchaImg!=null) setState(()=> _captchaImg=e.captchaImg);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
        } finally{ setState(()=> _loading=false); }
      }, child: const Text('Войти')),
    ]));
  }
}

// провайдер для SharedPreferences (прокинуть в main)
final sharedPrefsProvider = Provider<SharedPreferences>((ref)=> throw UnimplementedError());
