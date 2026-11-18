import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/vk/vk_api.dart';

class VkChromeAuthPage extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const VkChromeAuthPage({super.key, required this.onSuccess});
  @override
  ConsumerState<VkChromeAuthPage> createState() => _VkChromeAuthPageState();
}

class _VkChromeAuthPageState extends ConsumerState<VkChromeAuthPage> {
  StreamSubscription<Uri>? _sub;
  String? _error;
  bool _handling = false;
  String _currentClientId = VkApi.oauthClientId;
  String _authUrl = '';

  @override
  void initState() {
    super.initState();
    _initLinks();
    _buildUrl(_currentClientId);
  }

  void _buildUrl(String clientId) {
    _currentClientId = clientId;
    // Сайт как ты просил — oauth.vk.com token, как в браузере 1a/1b (405 с токеном)
    final scope = VkApi.oauthFallbackScopes[clientId] ?? VkApi.oauthScopeSite;
    // используем oauth.vk.ru/blank.html — как ты тестил
    _authUrl = 'https://oauth.vk.com/authorize?client_id=$clientId&scope=$scope&redirect_uri=https://oauth.vk.ru/blank.html&display=mobile&response_type=token&v=5.131&revoke=1&state=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _initLinks() async {
    final appLinks = AppLinks();
    // Холодный старт — если приложение открыли по ссылке
    try {
      final initial = await appLinks.getInitialLink();
      if (initial != null) _handleUri(initial);
    } catch (_) {}
    _sub = appLinks.uriLinkStream.listen(_handleUri, onError: (_) {});
  }

  Future<void> _handleUri(Uri uri) async {
    final url = uri.toString();
    if (!url.contains('access_token') && !url.contains('blank.html')) return;
    if (_handling) return;
    _handling = true;
    final token = _extractToken(url);
    if (token != null && token.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('vk_account_state_secure_access_token', token);
      await prefs.setString('vk_music_token', token);
      try {
        final frag = uri.fragment;
        final qp = Uri.splitQueryString(frag);
        final uid = qp['user_id'];
        if (uid != null) await prefs.setInt('vk_account_state_secure_user_id', int.tryParse(uid) ?? 0);
        final exp = qp['expires_in'];
        if (exp != null) await prefs.setInt('vk_account_state_secure_expires_at_ms', DateTime.now().millisecondsSinceEpoch + (int.tryParse(exp) ?? 86400) * 1000);
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('VK вход успешен ($_currentClientId)')));
        widget.onSuccess();
      }
      _handling = false;
      return;
    }
    if (mounted) setState(() => _error = 'Не нашёл токен в $url');
    _handling = false;
  }

  String? _extractToken(String url) {
    try {
      final uri = Uri.parse(url);
      final frag = uri.fragment;
      if (frag.contains('access_token=')) return Uri.splitQueryString(frag)['access_token'];
      final re = RegExp(r'access_token=([A-Za-z0-9_\-\.]+)');
      return re.firstMatch(url)?.group(1);
    } catch (_) { return null; }
  }

  Future<void> _openChromeTab() async {
    setState(() => _error = null);
    final uri = Uri.parse(_authUrl);
    // Chrome Custom Tabs — внешний браузер, не WebView (там VK режет Unknown method)
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      setState(() => _error = 'Не удалось открыть браузер');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('VK ID — вход')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Icon(Icons.chrome_reader_mode_rounded, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text('Вход как на сайте vk.ru', style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Откроется Chrome — войди на vk.com, после вернёт в AURA. Unknown method в приложении больше не будет — это был WebView.', textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 12)),
          const SizedBox(height: 16),
          // Выбор clientId — по твоей просьбе сайт primary
          Wrap(spacing: 8, children: [
            ChoiceChip(label: const Text('Сайт 6287487'), selected: _currentClientId == '6287487', onSelected: (v) { if (v) setState(() => _buildUrl('6287487')); }),
            ChoiceChip(label: const Text('VK Video 51858169'), selected: _currentClientId == '51858169', onSelected: (v) { if (v) setState(() => _buildUrl('51858169')); }),
            ChoiceChip(label: const Text('Kate 6121396'), selected: _currentClientId == '6121396', onSelected: (v) { if (v) setState(() => _buildUrl('6121396')); }),
          ]),
          const SizedBox(height: 12),
          SelectableText(_authUrl, style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: FilledButton.icon(icon: const Icon(Icons.open_in_browser), label: const Text('Открыть в Chrome'), onPressed: _openChromeTab)),
          const SizedBox(height: 8),
          TextButton(onPressed: () async {
            // Ручной ввод токена — если Custom Tabs не перехватил (some ROMs)
            final c = TextEditingController();
            final token = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
              title: const Text('Вставь access_token'),
              content: TextField(controller: c, decoration: const InputDecoration(hintText: 'скопируй #access_token из адресной строки blank.html')),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')), FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Сохранить'))],
            ));
            if (token != null && token.isNotEmpty) {
              final clean = _extractToken(token) ?? token;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('vk_account_state_secure_access_token', clean);
              await prefs.setString('vk_music_token', clean);
              widget.onSuccess();
            }
          }, child: const Text('Вставить токен вручную')),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12))),
          const Spacer(),
          Text('После логина VK отдаст https://oauth.vk.ru/blank.html#access_token=... — даже с 405 это успех, как ты проверил в браузере (1a/1b).', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.6)), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
