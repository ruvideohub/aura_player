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
  WebViewController? _controller;
  String? _authorizeUrl;
  int _fallbackIndex = -1;
  String get _currentClientId => _fallbackIndex < 0 ? VkApi.oauthClientId : VkApi.oauthFallbackIds[_fallbackIndex];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _loadWithClient(String clientId, SharedPreferences prefs, VkAccountManager mgr) async {
    final start = await mgr.startLogin(prefs: prefs, clientIdOverride: clientId);
    final finalUrl = start.authorizeUrl;
    debugPrint('[VK_AUTH] authorizeUrl=$finalUrl clientId=$clientId');
    final controller = WebViewController()
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36 VKAndroidApp/8.12')
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) async {
          if (req.url.contains('access_token=')) {
            final ok = await _handleRedirect(req.url, prefs);
            if (ok) return NavigationDecision.prevent;
          }
          if (req.url.contains('blank.html') || req.url.contains('oauth.vk.')) {
            final parsed = await _handleRedirect(req.url, prefs);
            if (parsed) return NavigationDecision.prevent;
          }
          if (req.url.contains('Unknown%20method') || req.url.contains('error_code=3')) {
            _tryFallback('Unknown method [3] на $clientId');
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onUrlChange: (change) async {
          final u = change.url ?? '';
          if (u.contains('access_token=')) await _handleRedirect(u, prefs);
        },
        onPageFinished: (url) async {
          if (url.contains('blank.html') || url.contains('access_token=')) await _handleRedirect(url, prefs);
          if (url.contains('oauth.vk.com') || url.contains('oauth.vk.ru') || url.contains('vk.ru') || url.contains('blank.html')) {
            _checkPageForError();
          }
        },
        onWebResourceError: (err) async {
          final u = err.url ?? '';
          debugPrint('[VK_AUTH] onWebResourceError ${err.errorCode} ${err.description} url=$u');
          if (u.contains('access_token=')) await _handleRedirect(u, prefs);
        },
      ));
    _controller = controller;
    setState(() {
      _authorizeUrl = finalUrl;
      _loading = false;
      _error = null;
      _successFired = false;
    });
    await controller.loadRequest(Uri.parse(finalUrl));
  }

  Future<void> _tryFallback(String reason) async {
    if (_fallbackIndex + 1 >= VkApi.oauthFallbackIds.length) {
      setState(() => _error = '$reason — все фоллбеки перебраны');
      return;
    }
    _fallbackIndex++;
    final nextId = VkApi.oauthFallbackIds[_fallbackIndex];
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Пробую фоллбек $nextId: $reason')));
    final prefs = await SharedPreferences.getInstance();
    final mgr = ref.read(vkAccountManagerProvider);
    await _loadWithClient(nextId, prefs, mgr);
  }

  Future<void> _checkPageForError() async {
    try {
      final c = _controller;
      if (c == null) return;
      final html = await c.runJavaScriptReturningResult('document.documentElement.innerText') as String?;
      final txt = html?.toString() ?? '';
      if (txt.contains('Unknown method') || txt.contains('Unknown method passed') || txt.contains('[3]')) {
        _tryFallback(txt.replaceAll('"', '').substring(0, 200));
      }
    } catch (_) {}
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final mgr = ref.read(vkAccountManagerProvider);
    await mgr.restore(prefs);
    if (mgr.session != null && mgr.session!.isActive()) {
      widget.onSuccess();
      return;
    }
    _fallbackIndex = -1;
    await _loadWithClient(VkApi.oauthClientId, prefs, mgr);
  }

  bool _successFired = false;
  Future<bool> _handleRedirect(String url, SharedPreferences prefs) async {
    // 1) Сначала всегда пробуем прямой токен из фрагмента — для oauth.vk.com он приходит даже с 405
    if (url.contains('access_token=')) {
      final token = _extractToken(url);
      if (token != null && token.isNotEmpty) {
        await prefs.setString('vk_account_state_secure_access_token', token);
        await prefs.setString('vk_music_token', token);
        // user_id тоже в фрагменте — сохраним для audio.get
        try {
          final frag = Uri.parse(url).fragment;
          final qp = Uri.splitQueryString(frag);
          final uid = qp['user_id'];
          if (uid != null) await prefs.setInt('vk_account_state_secure_user_id', int.tryParse(uid) ?? 0);
          final exp = qp['expires_in'];
          if (exp != null) await prefs.setInt('vk_account_state_secure_expires_at_ms', DateTime.now().millisecondsSinceEpoch + (int.tryParse(exp) ?? 86400) * 1000);
        } catch (_) {}
        if (!_successFired && mounted) {
          _successFired = true;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('VK ID: вход успешен (${_currentClientId})')));
          widget.onSuccess();
        }
        return true;
      }
    }
    // 2) PKCE code flow для id.vk.com
    final mgr = ref.read(vkAccountManagerProvider);
    final err = await mgr.handleRedirect(url, prefs: prefs);
    if (err == null) {
      if (!_successFired && mounted) {
        _successFired = true;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('VK ID: вход успешен')));
        widget.onSuccess();
      }
      return true;
    }
    // 3) Показываем ошибку только если это реально редирект с ошибкой
    if (url.contains('blank.html') && (url.contains('error') || url.contains('code='))) {
      if (url.contains('error=') && !url.contains('access_token=')) {
        // access_token мог быть рядом с error=405 — уже поймали выше
        if (mounted) setState(() => _error = err);
        return false;
      }
    }
    // Для других URL не спамим ошибкой — просто ждём токен
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
    if (_authorizeUrl == null || _controller == null) {
      return const Center(child: Text('Не удалось создать сессию'));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('VK ID — вход')),
      body: Column(children: [
        if (_authorizeUrl != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: SelectableText(_authorizeUrl!, style: const TextStyle(fontSize: 9, fontFamily: 'monospace')),
          ),
        Expanded(child: WebViewWidget(controller: _controller!)),
      ]),
    );
  }
}
