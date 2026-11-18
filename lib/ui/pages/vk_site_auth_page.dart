import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../services/vk/vk_api.dart';

/// Чистая авторизация как сайт: входим на vk.ru, тащим куки + токен из WebView.
/// Без ручного копирования ссылок, без Chrome Custom Tabs — всё внутри приложения.
class VkSiteAuthPage extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const VkSiteAuthPage({super.key, required this.onSuccess});
  @override
  ConsumerState<VkSiteAuthPage> createState() => _VkSiteAuthPageState();
}

class _VkSiteAuthPageState extends ConsumerState<VkSiteAuthPage> {
  late WebViewController _ctrl;
  bool _loading = true;
  bool _loggedIn = false;
  String _status = 'Загрузка vk.ru...';
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36')
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) async {
          // Ловим токен с blank.html сразу (даже с 405)
          if (req.url.contains('access_token=')) {
            _handleTokenUrl(req.url);
            return NavigationDecision.prevent;
          }
          if (req.url.contains('oauth.vk.ru/blank.html') || req.url.contains('oauth.vk.com/blank.html')) {
            // Может быть без фрагмента — проверяем
            if (req.url.contains('access_token=')) await _handleTokenUrl(req.url);
          }
          return NavigationDecision.navigate;
        },
        onUrlChange: (c) async {
          final u = c.url ?? '';
          if (u.contains('access_token=')) await _handleTokenUrl(u);
          // Детектим успешный логин на сайте — можно автоматом запросить токен
          if (!_loggedIn && (u.contains('vk.ru/feed') || u.contains('vk.com/feed') || u.contains('m.vk.ru/feed') || u.contains('vk.ru/id') || u.contains('vk.com/id'))) {
            setState(() {
              _loggedIn = true;
              _status = 'Вошёл — получаю токен vkvideoapp...';
            });
            // Через 1с дергаем authorize — куки уже есть, токен вернётся автоматом
            Future.delayed(const Duration(seconds: 1), _requestToken);
          }
        },
        onPageFinished: (url) async {
          setState(() => _loading = false);
          if (url.contains('vk.ru') || url.contains('vk.com')) {
            setState(() => _status = _loggedIn ? 'Авторизован — жми «Получить токен»' : 'Войди на сайте VK');
            // Проверяем не залогинен ли уже (есть профиль)
            _checkLoggedIn();
          }
          if (url.contains('access_token=')) await _handleTokenUrl(url);
        },
      ))
      ..loadRequest(Uri.parse('https://vk.ru/login'));

    // Также ловим blank.html через JS (фрагмент не всегда в URL)
    Future.delayed(const Duration(seconds: 2), _watchForToken);
  }

  Future<void> _watchForToken() async {
    while (mounted && !_loggedIn) {
      await Future.delayed(const Duration(milliseconds: 800));
      try {
        final url = await _ctrl.currentUrl();
        if (url != null && url.contains('access_token=')) await _handleTokenUrl(url);
      } catch (_) {}
    }
  }

  Future<void> _checkLoggedIn() async {
    try {
      final res = await _ctrl.runJavaScriptReturningResult("document.documentElement.innerText.includes('Профиль') || document.documentElement.innerText.includes('Новости') || document.cookie.includes('remixsid')");
      if (res.toString().contains('true')) {
        if (!_loggedIn && mounted) setState(() {
          _loggedIn = true;
          _status = 'Куки найдены — можно получать токен';
        });
      }
    } catch (_) {}
  }

  Future<void> _requestToken() async {
    setState(() {
      _status = 'Запрашиваю токен vkvideoapp ${VkApi.oauthClientId}...';
      _error = null;
    });
    // Грузим authorize прямо в этом WebView — куки сайта уже есть
    final url = VkApi.oauthAuthorizeUrl(state: DateTime.now().millisecondsSinceEpoch.toString());
    await _ctrl.loadRequest(Uri.parse(url));
  }

  Future<void> _handleTokenUrl(String url) async {
    final token = _extractToken(url);
    if (token == null || token.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vk_account_state_secure_access_token', token);
    await prefs.setString('vk_music_token', token);
    // user_id / expires_in из фрагмента
    try {
      final uri = Uri.parse(url);
      final frag = uri.fragment;
      if (frag.isNotEmpty) {
        final qp = Uri.splitQueryString(frag);
        final uid = qp['user_id']; if (uid != null) await prefs.setInt('vk_account_state_secure_user_id', int.tryParse(uid) ?? 0);
        final exp = qp['expires_in']; if (exp != null) await prefs.setInt('vk_account_state_secure_expires_at_ms', DateTime.now().millisecondsSinceEpoch + (int.tryParse(exp) ?? 86400) * 1000);
      }
    } catch (_) {}
    // Сохраняем куки тоже (для web.api.vk.ru)
    try {
      final cookies = await _ctrl.runJavaScriptReturningResult('document.cookie') as String?;
      if (cookies != null) await prefs.setString('vk_cookies', cookies);
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('VK вход успешен — токен сохранён')));
      widget.onSuccess();
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('VK — вход как на сайте'),
        actions: [
          if (_loggedIn) TextButton(onPressed: _requestToken, child: const Text('Получить токен')),
        ],
      ),
      body: Column(children: [
        Material(
          color: _loggedIn ? Colors.green.withOpacity(0.15) : theme.colorScheme.surfaceVariant,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Icon(_loggedIn ? Icons.check_circle : Icons.info_outline, size: 18, color: _loggedIn ? Colors.green : theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(_status, style: const TextStyle(fontSize: 12))),
              if (_loggedIn) FilledButton(onPressed: _requestToken, child: const Text('Получить токен')),
            ]),
          ),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12))),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(child: WebViewWidget(controller: _ctrl)),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.refresh), label: const Text('Перезагрузить'), onPressed: () => _ctrl.reload())),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.cookie), label: const Text('Показать куки'), onPressed: () async {
              final c = await _ctrl.runJavaScriptReturningResult('document.cookie');
              if (!mounted) return;
              showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Куки'), content: SingleChildScrollView(child: SelectableText(c.toString())), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть'))]));
            })),
          ]),
        ),
      ]),
    );
  }
}
