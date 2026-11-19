import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/vk_music/vk_token_storage.dart';
import 'vk_music_page.dart';

/// Helper + WebView с автоперехватом blank.html#access_token
class VkWebViewHelper {
  // 6767438 — VK Music (UMA) — единственный рабочий per user 04:32, проверен трижды
  static const _siteUrl =
      'https://oauth.vk.com/authorize?client_id=6767438&scope=audio,offline&redirect_uri=https://oauth.vk.com/blank.html&display=mobile&response_type=token&revoke=1&v=5.131';
  // Запасной — старый Kate (тоже даёт audio)
  static const _altUrl =
      'https://oauth.vk.com/authorize?client_id=6121396&scope=audio,offline&redirect_uri=https://oauth.vk.com/blank.html&display=mobile&response_type=token&revoke=1';

  static String url({bool alt = false}) => alt ? _altUrl : _siteUrl;

  static Future<void> openBrowser({bool alt = false}) async {
    final uri = Uri.parse(url(alt: alt));
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static String? extractTokenFromUrl(String url) {
    try {
      final uri = Uri.parse(url.trim());
      final frag = uri.fragment;
      if (frag.contains('access_token=')) {
        final params = Uri.splitQueryString(frag);
        return params['access_token'];
      }
      if (uri.queryParameters.containsKey('access_token')) {
        return uri.queryParameters['access_token'];
      }
      if (url.length > 70 && !url.contains(' ') && !url.contains('/')) {
        return url.trim();
      }
      final re = RegExp(r'access_token=([a-zA-Z0-9_\-]+)');
      final m = re.firstMatch(url);
      if (m != null) return m.group(1);
    } catch (_) {}
    return null;
  }

  static int? extractUserIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url.trim());
      final frag = uri.fragment;
      if (frag.contains('user_id=')) {
        final params = Uri.splitQueryString(frag);
        return int.tryParse(params['user_id'] ?? '');
      }
      if (uri.queryParameters.containsKey('user_id')) return int.tryParse(uri.queryParameters['user_id']!);
      final re = RegExp(r'user_id=(\d+)');
      final m = re.firstMatch(url);
      if (m != null) return int.tryParse(m.group(1)!);
    } catch (_) {}
    return null;
  }
}

/// WebView — открывает oauth.vk.com/authorize и ЛОВИТ редирект на blank.html автоматически
class VkBlankWebView extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  final bool alt;
  const VkBlankWebView({super.key, required this.onSuccess, this.alt = false});
  @override
  ConsumerState<VkBlankWebView> createState() => _VkBlankWebViewState();
}

class _VkBlankWebViewState extends ConsumerState<VkBlankWebView> {
  late final WebViewController _ctrl;
  bool _done = false;
  String? _curUrl;

  @override
  void initState() {
    super.initState();
    final target = VkWebViewHelper.url(alt: widget.alt);
    _curUrl = target;
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36')
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) {
          _tryCapture(req.url);
          return NavigationDecision.navigate;
        },
        onUrlChange: (c) {
          if (c.url != null) {
            _curUrl = c.url;
            _tryCapture(c.url!);
          }
        },
        onPageFinished: (url) async {
          _curUrl = url;
          await _tryCapture(url);
          // fragment (#access_token) не всегда в url — берём из JS
          try {
            final href = await _ctrl.runJavaScriptReturningResult('window.location.href') as Object?;
            final s = href.toString().replaceAll('"', '').replaceAll("'", "");
            if (s.contains('access_token=')) await _tryCapture(s);
          } catch (_) {}
        },
        onWebResourceError: (e) async {
          final u = e.url ?? '';
          if (u.contains('access_token=')) await _tryCapture(u);
        },
      ))
      ..loadRequest(Uri.parse(target));
  }

  Future<void> _tryCapture(String url) async {
    if (_done) return;
    if (!url.contains('access_token=')) return;
    final token = VkWebViewHelper.extractTokenFromUrl(url);
    if (token == null || token.isEmpty) return;
    _done = true;
    final uid = VkWebViewHelper.extractUserIdFromUrl(url) ?? 0;
    final prefs = ref.read(sharedPrefsProvider);
    // дублируем ключи как в старом _ManualVkLogin для совместимости
    await VkTokenStorage(prefs).save(token, uid);
    await prefs.setString('vk_music_token', token);
    if (uid != 0) await prefs.setInt('vk_music_uid', uid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('VK токен пойман из blank.html ✓')));
    widget.onSuccess();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.alt ? 'VK вход — 6121396' : 'VK вход — 6767438'),
        actions: [
          IconButton(icon: const Icon(Icons.open_in_browser_rounded), tooltip: 'Внешний браузер', onPressed: () => VkWebViewHelper.openBrowser(alt: widget.alt)),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => _ctrl.reload()),
        ],
      ),
      body: Column(
        children: [
          if (_curUrl != null)
            Padding(
              padding: const EdgeInsets.all(6),
              child: SelectableText(_curUrl!, style: const TextStyle(fontSize: 9, fontFamily: 'monospace')),
            ),
          Expanded(child: WebViewWidget(controller: _ctrl)),
        ],
      ),
    );
  }
}

// Совместимость: старый bottom-sheet (теперь просто открывает то же, но ручной fallback оставлен)
class VkWebAuthSheet extends StatefulWidget {
  final void Function(String token, int uid) onToken;
  const VkWebAuthSheet({super.key, required this.onToken});
  @override
  State<VkWebAuthSheet> createState() => _VkWebAuthSheetState();
}

class _VkWebAuthSheetState extends State<VkWebAuthSheet> {
  final _ctrl = TextEditingController();
  bool _alt = false;
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Вход через браузер', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Откроется vk.com — войди → Разрешить, токен поймается автоматом. Если не — вставь ссылку вручную.', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => VkWebViewHelper.openBrowser(alt: _alt),
            icon: const Icon(Icons.open_in_browser_rounded),
            label: Text(_alt ? 'Открыть VK (6121396)' : 'Открыть VK (6767438) ✓'),
          ),
          TextButton(
            onPressed: () => setState(() => _alt = !_alt),
            child: Text(_alt ? 'Переключить на 6767438' : 'Попробовать 6121396'),
          ),
          const Divider(),
          TextField(
            controller: _ctrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Вставь ссылку blank.html или токен',
              hintText: 'https://oauth.vk.com/blank.html#access_token=...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () {
              final token = VkWebViewHelper.extractTokenFromUrl(_ctrl.text);
              final uid = VkWebViewHelper.extractUserIdFromUrl(_ctrl.text) ?? 0;
              if (token == null || token.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не нашёл access_token в ссылке')));
                return;
              }
              widget.onToken(token, uid);
              Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ]),
      ),
    );
  }
}
