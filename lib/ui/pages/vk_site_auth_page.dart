import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/vk/vk_account_manager.dart';

/// WebView как в твоём оригинале: startLogin → intercept blank.html → handleRedirect.
class VkSiteAuthPage extends StatefulWidget {
  final VoidCallback onSuccess;
  const VkSiteAuthPage({super.key, required this.onSuccess});
  @override
  State<VkSiteAuthPage> createState() => _VkSiteAuthPageState();
}

class _VkSiteAuthPageState extends State<VkSiteAuthPage> {
  late final WebViewController _ctrl;
  late final VkAccountManager _mgr;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _mgr = VkAccountManager();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36')
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) async {
          final url = req.url;
          if (url.contains('blank.html')) {
            final err = await _mgr.handleRedirect(url);
            if (err == null && !_done) {
              _done = true;
              if (mounted) widget.onSuccess();
            }
            // не лочим навигацию — пусть blank отработает, но токен уже взят
          }
          return NavigationDecision.navigate;
        },
        onUrlChange: (c) async {
          final u = c.url ?? '';
          if (u.contains('blank.html') && u.contains('code=')) {
            final err = await _mgr.handleRedirect(u);
            if (err == null && !_done) {
              _done = true;
              if (mounted) widget.onSuccess();
            }
          }
        },
      ));

    _start();
  }

  Future<void> _start() async {
    final start = await _mgr.startLogin();
    await _ctrl.loadRequest(Uri.parse(start.authorizeUrl));
  }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('VK — вход')), body: WebViewWidget(controller: _ctrl));
}
