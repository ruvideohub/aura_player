import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/vk/vk_lkmp_auth.dart';

/// Точная копия UI LKMP (slide_auth_code.xml + route_auth.xml)
/// #131313 фон, 38dp отступы, 18sp заголовки, как в оригинале
class VkLkmpAuthPage extends StatefulWidget {
  final VoidCallback? onSuccess;
  const VkLkmpAuthPage({super.key, this.onSuccess});
  @override
  State<VkLkmpAuthPage> createState() => _VkLkmpAuthPageState();
}

enum _Step { login, chooseMethod, code, password }

class _VkLkmpAuthPageState extends State<VkLkmpAuthPage> {
  final _http = http.Client();
  late final VkLkmpAuth _auth;
  _Step _step = _Step.login;
  final _loginCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _title = 'Вход в VK';
  String _info = '';
  bool _loading = false;
  String? _captchaImg, _captchaSid;
  String _sid = '';
  List<Map<String, String>> _methods = [];
  String _currentMethod = '';
  String _currentInfo = '';

  @override
  void initState() {
    super.initState();
    _auth = VkLkmpAuth(_http);
  }

  @override
  void dispose() {
    _loginCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _http.close();
    super.dispose();
  }

  Future<void> _doLogin() async {
    if (_loginCtrl.text.trim().length < 4) {
      setState(() => _info = 'Слишком короткий логин');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await _auth.validateAccount(phone: _loginCtrl.text.trim());
      // LKMP: сначала проверяем error
      if (res['error'] != null) {
        final err = res['error'] as Map;
        final code = err['error_code'] as int? ?? 0;
        if (code == 9) {
          // Flood — точно как у LKMP, только человеческий текст
          setState(() => _info = 'Слишком много попыток. Подождите 2–3 минуты и попробуйте снова.\nLKMP тоже ловит это при спаме — у него тот же error 9, просто он ставит задержку.');
          return;
        }
        setState(() => _info = '${err['error_text'] ?? err['error_msg'] ?? err}');
        return;
      }
      final resp = res['response'] ?? res;
      _sid = resp['sid']?.toString() ?? '';
      if (resp['next_step'] != null) {
        final ns = resp['next_step'] as Map;
        final vm = ns['verification_method']?.toString() ?? '';
        if (vm.isNotEmpty) {
          _showCodeFor(vm, ns['info']?.toString() ?? '');
          return;
        }
      }
      // пробуем getVerificationMethods
      final vmRes = await _auth.getVerificationMethods(sid: _sid);
      if (vmRes['error'] != null) {
        final err = vmRes['error'] as Map;
        if (err['error_code'] == 9) {
          setState(() => _info = 'Слишком много попыток. Подождите пару минут — VK ограничил частоту.');
          return;
        }
      }
      final list = (vmRes['response']?['verification_methods'] as List?) ?? [];
      if (list.isNotEmpty) {
        setState(() {
          _methods = list.map((e) => {'method': e['method'].toString(), 'info': e['info']?.toString() ?? ''}).toList();
          _step = _Step.chooseMethod;
          _title = 'Выберите способ подтверждения';
          _info = '';
        });
      } else if (_sid.isNotEmpty) {
        // fallback: если sid есть — сразу показываем ввод кода
        _showCodeFor('sms', '');
      } else {
        setState(() => _info = 'Неизвестный ответ: $resp');
      }
    } catch (e) {
      final s = e.toString();
      if (s.contains('captcha')) {
        // попробуем вытащить captcha_img
        setState(() => _info = 'Нужна капча — попробуйте через WebView');
      } else {
        setState(() => _info = s);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCodeFor(String method, String info) {
    String title = 'Введите код для подтверждения';
    if (method == 'sms') title = 'Введите код из смс';
    if (method == 'push') title = 'Введите код из уведомления';
    if (method == 'email') title = 'Введите код из письма';
    if (method == 'password') {
      setState(() {
        _step = _Step.password;
        _title = 'Введите пароль';
        _currentMethod = method;
        _info = '';
      });
      return;
    }
    if (method == 'reserve_code') title = 'Введите резервный код';
    if (method == 'codegen') title = 'Введите код';
    setState(() {
      _step = _Step.code;
      _title = title;
      _currentMethod = method;
      _currentInfo = info;
      _info = info.isNotEmpty ? (method == 'sms' ? 'На номер $info поступит SMS или звонок-сброс' : method == 'email' ? 'Письмо отправлено на $info' : method == 'push' ? 'Push на устройство $info' : info) : '';
    });
  }

  Future<void> _submitCode() async {
    if (_codeCtrl.text.trim().isEmpty) {
      setState(() => _info = 'Введите код');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await _auth.checkOtp(code: _codeCtrl.text.trim(), sid: _sid);
      // если успешно — внутри exchange_token → access_token
      if (res['response'] != null || res['access_token'] != null) {
        // пробуем достать токен
        final token = res['response']?['access_token'] ?? res['access_token'];
        if (token != null) {
          final p = await SharedPreferences.getInstance();
          await p.setString('vk_music_token', token.toString());
          if (res['response']?['exchange_token'] != null) await p.setString('vk_exchange_token', res['response']['exchange_token'].toString());
          if (mounted && widget.onSuccess != null) widget.onSuccess!();
          if (mounted) Navigator.of(context).pop(true);
          return;
        }
        // иначе считаем успехом и пробуем refresh
        await _auth.refreshByExchangeToken();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Код принят, токен обновлён')));
          if (widget.onSuccess != null) widget.onSuccess!();
          Navigator.of(context).pop(true);
        }
        return;
      }
      setState(() => _info = 'Неверный код: $res');
    } catch (e) {
      setState(() => _info = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitPassword() async {
    if (_passCtrl.text.length <= 3) {
      setState(() => _info = 'Слишком короткий пароль');
      return;
    }
    setState(() => _loading = true);
    try {
      // LKMP для пароля использует тот же validateAccount с другим flow — пока через прямой oauth
      final uri = Uri.parse('https://oauth.vk.ru/token');
      final r = await _http.post(uri, body: {
        'grant_type': 'password',
        'client_id': '2274003',
        'client_secret': 'hHbZxrka2uZ6jB1inYsH',
        'username': _loginCtrl.text.trim(),
        'password': _passCtrl.text,
        'scope': 'all',
        'v': '5.276',
        '2fa_supported': '1',
        'sak_version': '1.144.0',
        'flow_type': 'tg_flow',
      });
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      if (j['access_token'] != null) {
        final p = await SharedPreferences.getInstance();
        await p.setString('vk_music_token', j['access_token'].toString());
        if (j['exchange_token'] != null) await p.setString('vk_exchange_token', j['exchange_token'].toString());
        if (j['user_id'] != null) await p.setInt('vk_music_uid', j['user_id'] as int);
        if (mounted) {
          if (widget.onSuccess != null) widget.onSuccess!();
          Navigator.of(context).pop(true);
        }
        return;
      }
      if (j['error'] == 'need_validation') {
        // нужен код — переходим
        _sid = j['sid']?.toString() ?? _sid;
        _showCodeFor('sms', '');
        return;
      }
      setState(() => _info = 'Ошибка: ${j['error_description'] ?? j}');
    } catch (e) {
      setState(() => _info = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131313),
      appBar: AppBar(backgroundColor: const Color(0xFF131313), elevation: 0, iconTheme: const IconThemeData(color: Colors.white), title: const Text('Вход', style: TextStyle(color: Colors.white))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 38),
          child: _buildStep(),
        ),
      ),
    );
  }

  Widget _buildStep() {
    if (_step == _Step.chooseMethod) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Выберите способ подтверждения', style: TextStyle(color: Colors.white, fontSize: 18), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ..._methods.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D2D2D), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: () => _showCodeFor(m['method']!, m['info']!),
                    child: Text(_labelFor(m['method']!, m['info']!), style: const TextStyle(color: Colors.white)),
                  ),
                ),
              )),
        ],
      );
    }
    if (_step == _Step.code) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_title, style: const TextStyle(color: Colors.white, fontSize: 18), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          if (_captchaImg != null) Image.network(_captchaImg!, height: 50, width: 130),
          TextField(
            controller: _codeCtrl,
            style: const TextStyle(color: Color(0xFFC8C8C8), fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Код',
              hintStyle: const TextStyle(color: Color(0xFFD5D5D5)),
              filled: true,
              fillColor: const Color(0xFF1F1F1F),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          if (_info.isNotEmpty) Text(_info, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0077FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: _loading ? null : _submitCode,
              child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Подтвердить', style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D2D2D), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () {},
              child: const Text('Отправить повторно СМС', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      );
    }
    if (_step == _Step.password) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Введите пароль', style: TextStyle(color: Colors.white, fontSize: 18), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextField(
            controller: _passCtrl,
            obscureText: true,
            style: const TextStyle(color: Color(0xFFC8C8C8), fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Пароль',
              hintStyle: const TextStyle(color: Color(0xFFD5D5D5)),
              filled: true,
              fillColor: const Color(0xFF1F1F1F),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          if (_info.isNotEmpty) Text(_info, style: const TextStyle(color: Colors.white, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0077FF)),
              onPressed: _loading ? null : _submitPassword,
              child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Войти', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      );
    }
    // login
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Вход в VK', style: TextStyle(color: Colors.white, fontSize: 18), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        TextField(
          controller: _loginCtrl,
          style: const TextStyle(color: Color(0xFFC8C8C8), fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Телефон или почта',
            hintStyle: const TextStyle(color: Color(0xFFD5D5D5)),
            filled: true,
            fillColor: const Color(0xFF1F1F1F),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 8),
        if (_info.isNotEmpty) Text(_info, style: const TextStyle(color: Color(0xFFFF5252), fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0077FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: _loading ? null : _doLogin,
            child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Далее', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  String _labelFor(String method, String info) {
    switch (method) {
      case 'sms': return 'Номер телефона $info';
      case 'push': return 'Уведомление на устройство $info';
      case 'email': return 'Электронная почта $info';
      case 'password': return 'Ввести пароль';
      case 'reserve_code': return 'Ввести резервный код';
      case 'codegen': return 'Приложение для генерации кодов';
      default: return '$method - $info';
    }
  }
}
