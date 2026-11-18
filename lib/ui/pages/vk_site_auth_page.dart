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
          if (u.contains('access_token=')) { await _handleTokenUrl(u); return; }
          // Вошёл — сразу тащим токен без кнопок
          if (u.contains('vk.ru/feed') || u.contains('vk.com/feed') || u.contains('m.vk.ru/feed') || u.contains('/feed') || u.contains('/id') && u.contains('vk.ru')) {
            if (!_loggedIn) {
              _loggedIn = true;
              _requestToken();
            }
          }
        },
        onPageFinished: (url) async {
          setState(() => _loading = false);
          if (url.contains('access_token=')) { await _handleTokenUrl(url); return; }
          if (url.contains('oauth.vk.ru/blank.html') || url.contains('oauth.vk.com/blank.html')) {
            // blank без токена = ошибка, но токен может быть уже в URL
            await _handleTokenUrl(url);
            return;
          }
          // Детектим логин по куке — сразу дергаем токен
          if (url.contains('vk.ru') || url.contains('vk.com')) {
            final hasSession = await _hasSession();
            if (hasSession && !_loggedIn) {
              _loggedIn = true;
              _requestToken();
            }
          }
        },
      ))
      ..loadRequest(Uri.parse('https://vk.ru/login'));

    // Фоновый вотчер токена
    _pollToken();
  }

  Future<bool> _hasSession() async {
    try {
      final res = await _ctrl.runJavaScriptReturningResult("document.cookie.includes('remixsid') || document.cookie.includes('remixq') || document.cookie.includes('remixns'))");
      return res.toString().contains('true');
    } catch (_) { return false; }
  }

  Future<void> _pollToken() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) break;
      try {
        final url = await _ctrl.currentUrl();
        if (url != null && url.contains('access_token=')) { await _handleTokenUrl(url); break; }
        // Также чекаем куки — если залогинен, сразу токен
        if (!_loggedIn && url != null && (url.contains('vk.ru') || url.contains('vk.com'))) {
          if (await _hasSession()) {
            _loggedIn = true;
            _requestToken();
            break;
          }
        }
      } catch (_) {}
    }
  }

  bool _tokenRequested = false;
  Future<void> _requestToken() async {
    if (_tokenRequested) return;
    _tokenRequested = true;
    final url = VkApi.oauthAuthorizeUrl(state: DateTime.now().millisecondsSinceEpoch.toString());
    await _ctrl.loadRequest(Uri.parse(url));
  }

  Future<void> _handleTokenUrl(String url) async {
    if (_done) return;
    final token = _extractToken(url);
    if (token == null || token.isEmpty) return;
    _done = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vk_account_state_secure_access_token', token);
    await prefs.setString('vk_music_token', token);
    try {
      final uri = Uri.parse(url);
      final frag = uri.fragment;
      if (frag.isNotEmpty) {
        final qp = Uri.splitQueryString(frag);
        final uid = qp['user_id']; if (uid != null) await prefs.setInt('vk_account_state_secure_user_id', int.tryParse(uid) ?? 0);
        final exp = qp['expires_in']; if (exp != null) await prefs.setInt('vk_account_state_secure_expires_at_ms', DateTime.now().millisecondsSinceEpoch + (int.tryParse(exp) ?? 86400) * 1000);
      }
      final cookies = await _ctrl.runJavaScriptReturningResult('document.cookie') as String?;
      if (cookies != null) await prefs.setString('vk_cookies', cookies);
    } catch (_) {}
    if (mounted) widget.onSuccess();
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

  bool _done = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VK — вход')),
      body: WebViewWidget(controller: _ctrl),
    );
  }
}
