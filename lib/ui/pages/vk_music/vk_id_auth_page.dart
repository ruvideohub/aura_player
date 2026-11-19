import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../services/vk_music/vk_id_auth.dart';
import '../../../services/vk_music/vk_token_storage.dart';
import 'vk_music_page.dart';
import 'vk_webview_page.dart';

/// Нативный VK ID флоу: телефон → код → пароль (как в vkmauth).
/// WebView — последняя линия обороны (кнопка внизу).
class VkIdAuthPage extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const VkIdAuthPage({super.key, required this.onSuccess});
  @override
  ConsumerState<VkIdAuthPage> createState() => _VkIdAuthPageState();
}

enum _Step { phone, code, done }

class _VkIdAuthPageState extends ConsumerState<VkIdAuthPage> {
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  _Step _step = _Step.phone;
  bool _loading = false;
  String? _error;
  String? _sid;
  String? _deviceId;
  String? _anonToken;
  int _delay = 30;
  String _validationType = '';
  String _resendWay = '';

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _doValidatePhone() async {
    final phone = _phoneCtrl.text.trim();
    final pass = _passCtrl.text;
    if (phone.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Введи телефон и пароль');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final auth = VkIdAuth(http.Client());
      final deviceId = 'aura_${DateTime.now().millisecondsSinceEpoch}_${phone.hashCode.abs()}';
      _deviceId = deviceId;
      final anon = await auth.getAnonymousToken(deviceId);
      _anonToken = anon.token;
      final val = await auth.validatePhone(phone: phone, sid: '', anon: anon);
      setState(() {
        _sid = val.sid;
        _delay = val.delay;
        _validationType = val.validationType;
        _resendWay = val.validationResend;
        _step = _Step.code;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Код отправлен: $_validationType (повтор через $_delay c)')));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _doConfirm() async {
    final phone = _phoneCtrl.text.trim();
    final pass = _passCtrl.text;
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) { setState(() => _error = 'Введи код'); return; }
    if (_sid == null || _deviceId == null || _anonToken == null) { setState(() => _error = 'Потеряна сессия, начни заново'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final auth = VkIdAuth(http.Client());
      final confirm = await auth.validatePhoneConfirm(deviceId: _deviceId!, code: code, phone: phone, anonToken: _anonToken!, sid: _sid!);
      final silent = await auth.getSilentToken(sid: confirm.sid, phone: phone, password: pass, anonymousToken: _anonToken!, deviceId: _deviceId!, twoFaSupported: confirm.has2Fa);
      final checked = await auth.checkSilentToken(token: silent.token, uuid: silent.uuid, anonToken: _anonToken!, deviceId: _deviceId!);
      final finalTok = await auth.getToken(deviceId: _deviceId!, uuid: checked.uuid, silentToken: checked.token);
      final prefs = ref.read(sharedPrefsProvider);
      await VkTokenStorage(prefs).save(finalTok.accessToken, 0);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('VK ID: токен получен')));
      widget.onSuccess();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openWebFallback() async {
    await showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => VkWebAuthSheet(onToken: (tok, uid) async {
          final prefs = ref.read(sharedPrefsProvider);
          await VkTokenStorage(prefs).save(tok, uid);
          widget.onSuccess();
        }));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(children: [
            Icon(Icons.lock_person_rounded, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            const Text('VK ID — вход', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 6),
            Text('Телефон → код (30-90с) → пароль. Работает когда прямой пароль заблокирован.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6))),
            const SizedBox(height: 16),
            if (_step == _Step.phone) ...[
              TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Телефон +7999...', prefixIcon: Icon(Icons.phone)), keyboardType: TextInputType.phone),
              const SizedBox(height: 8),
              TextField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Пароль VK', prefixIcon: Icon(Icons.lock_outline))),
              const SizedBox(height: 12),
              _loading ? const CircularProgressIndicator() : SizedBox(width: double.infinity, child: FilledButton(onPressed: _doValidatePhone, child: const Text('Получить код'))),
            ] else ...[
              Text('Код отправлен: $_validationType • повтор: $_resendWay • задержка ${_delay}с', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              TextField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'Код из SMS/пуша', prefixIcon: Icon(Icons.sms)), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Пароль (подтверждение)', prefixIcon: Icon(Icons.lock))),
              const SizedBox(height: 12),
              _loading ? const CircularProgressIndicator() : SizedBox(width: double.infinity, child: FilledButton(onPressed: _doConfirm, child: const Text('Подтвердить'))),
              TextButton(onPressed: () => setState(() => _step = _Step.phone), child: const Text('Назад')),
            ],
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12))),
            const Divider(height: 24),
            OutlinedButton.icon(onPressed: _openWebFallback, icon: const Icon(Icons.language_rounded), label: const Text('Войти через браузер (запасной)')),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () async {
                final c = TextEditingController();
                final tok = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(title: const Text('Токен вручную'), content: TextField(controller: c, decoration: const InputDecoration(hintText: 'access_token')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')), FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Сохранить'))]));
                if (tok != null && tok.isNotEmpty) {
                  await VkTokenStorage(ref.read(sharedPrefsProvider)).save(tok, 0);
                  widget.onSuccess();
                }
              },
              child: const Text('Вставить токен вручную'),
            ),
          ]),
        ),
      ),
    );
  }
}
