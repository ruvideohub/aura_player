import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Fallback через внешний браузер — использует ID самого сайта VK (6287487),
/// как просил пользователь (не блочится, т.к. это vk.com).
class VkWebViewHelper {
  // Основной — site ID vk.com (рекомендован после бана Kate 2024-06-25)
  static const _siteUrl =
      'https://oauth.vk.com/authorize?client_id=6287487&scope=audio,offline,messages&redirect_uri=https://oauth.vk.com/blank.html&display=mobile&response_type=token&revoke=1&v=5.131';
  // Запасной — старый Kate/UMA если site вдруг не даст audio
  static const _altUrl =
      'https://oauth.vk.com/authorize?client_id=6121396&scope=audio,offline&redirect_uri=https://oauth.vk.com/blank.html&display=mobile&response_type=token&revoke=1';

  static Future<void> openBrowser({bool alt = false}) async {
    final uri = Uri.parse(alt ? _altUrl : _siteUrl);
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
          const Text('Откроется vk.com — войди телефон→код→пароль, нажми Разрешить, скопируй ссылку из адресной строки.', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => VkWebViewHelper.openBrowser(alt: _alt),
            icon: const Icon(Icons.open_in_browser_rounded),
            label: Text(_alt ? 'Открыть VK (6121396)' : 'Открыть сайт VK (6287487) ✓'),
          ),
          TextButton(
            onPressed: () => setState(() => _alt = !_alt),
            child: Text(_alt ? 'Переключить на 6287487 (vk.com)' : 'Попробовать 6121396'),
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
