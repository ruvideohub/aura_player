import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Fallback авторизация через внешний браузер (WebView как последняя линия).
/// Открывает oauth.vk.com/authorize, пользователь логинится штатным VK ID (телефон→код→пароль),
/// затем копирует финальный URL blank.html#access_token и вставляет в AURA.
/// Мы парсим фрагмент и отдаём токен.
class VkWebViewHelper {
  static const _authUrl =
      'https://oauth.vk.com/authorize?client_id=6121396&scope=audio,offline&redirect_uri=https://oauth.vk.com/blank.html&display=mobile&response_type=token&revoke=1';
  static const _altUrl =
      'https://oauth.vk.com/authorize?client_id=6767438&scope=audio,offline&redirect_uri=https://oauth.vk.com/blank.html&display=mobile&response_type=token&revoke=1';

  static Future<void> openBrowser({bool alt = false}) async {
    final uri = Uri.parse(alt ? _altUrl : _authUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static String? extractTokenFromUrl(String url) {
    // url вида https://oauth.vk.com/blank.html#access_token=...&expires_in=0&user_id=...
    // или https://oauth.vk.com/blank.html?code=... (для code flow не нужен)
    try {
      final uri = Uri.parse(url.trim());
      // фрагмент после # содержит параметры
      final frag = uri.fragment;
      if (frag.contains('access_token=')) {
        final params = Uri.splitQueryString(frag);
        return params['access_token'];
      }
      // иногда токен в query (fallback)
      if (uri.queryParameters.containsKey('access_token')) {
        return uri.queryParameters['access_token'];
      }
      // если вставили просто токен без URL — считаем что это токен
      if (url.length > 70 && !url.contains(' ') && !url.contains('/')) {
        return url.trim();
      }
      // пробуем найти access_token= в сыром тексте
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
          const Text('Вход через браузер (запасной)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Откроется официальный сайт VK. Войди как обычно (телефон → код → пароль), нажми Разрешить, скопируй ссылку из адресной строки и вставь сюда.', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => VkWebViewHelper.openBrowser(alt: _alt),
            icon: const Icon(Icons.open_in_browser_rounded),
            label: Text(_alt ? 'Открыть VK Music (6767438)' : 'Открыть VK (6121396)'),
          ),
          TextButton(
            onPressed: () => setState(() => _alt = !_alt),
            child: Text(_alt ? 'Переключить на стандартный client_id' : 'Попробовать альтернативный client_id'),
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
