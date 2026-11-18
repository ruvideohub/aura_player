import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

import '../../services/vk/vk_account_manager.dart';
import '../../services/vk/vk_api.dart';

final vkAccountManagerProvider = Provider<VkAccountManager>((ref) {
  return VkAccountManager(http.Client());
});

class VkAuthPage extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const VkAuthPage({super.key, required this.onSuccess});
  @override
  ConsumerState<VkAuthPage> createState() => _VkAuthPageState();
}

class _VkAuthPageState extends ConsumerState<VkAuthPage> {
  bool _loading = true;
  String? _error;
  late WebViewController _controller;
  String? _authorizeUrl;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final mgr = ref.read(vkAccountManagerProvider);
    await mgr.restore(prefs);
    if (mgr.session != null && mgr.session!.isActive()) {
      widget.onSuccess();
      return;
    }
    final start = await mgr.startLogin(prefs);
    setState(() {
      _authorizeUrl = start.authorizeUrl;
      _loading = false;
    });
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) async {
          if (req.url.contains('blank.html') || req.url.contains('oauth.vk.')) {
            final parsed = await _handleRedirect(req.url, prefs);
            if (parsed) return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onPageFinished: (url) async {
          if (url.contains('blank.html')) {
            await _handleRedirect(url, prefs);
          }
        },
      ))
      ..loadRequest(Uri.parse(start.authorizeUrl));
  }

  Future<bool> _handleRedirect(String url, SharedPreferences prefs) async {
    // Пытаемся разобрать как PKCE redirect
    final mgr = ref.read(vkAccountManagerProvider);
    final err = await mgr.handleRedirect(url, prefs);
    if (err == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('VK ID: вход успешен')));
        widget.onSuccess();
      }
      return true;
    }
    // Если это не наш PKCE формат, пробуем fallback: прямой токен в фрагменте
    if (url.contains('access_token=')) {
      final token = _extractToken(url);
      if (token != null) {
        await prefs.setString('vk_account_state_secure_access_token', token);
        // Для совместимости со старым хранилищем
        await prefs.setString('vk_music_token', token);
        if (mounted) widget.onSuccess();
        return true;
      }
    }
    // Показать ошибку только если это действительно редирект с code/state
    if (url.contains('code=') || url.contains('error')) {
      setState(() => _error = err);
    }
    return false;
  }

  String? _extractToken(String url) {
    try {
      final uri = Uri.parse(url);
      final frag = uri.fragment;
      if (frag.contains('access_token=')) {
        return Uri.splitQueryString(frag)['access_token'];
      }
      final re = RegExp(r'access_token=([A-Za-z0-9_\-\.]+)');
      return re.firstMatch(url)?.group(1);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => _init(), child: const Text('Повторить')),
          ]),
        ),
      );
    }
    if (_authorizeUrl == null) {
      return const Center(child: Text('Не удалось создать сессию'));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('VK ID — вход')),
      body: WebViewWidget(controller: _controller),
    );
  }
}
