import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/vk/vk_lkmp_auth.dart';

/// Вход по флоу LKMP (route_auth.xml + слайды auth_steep_*).
///
/// Отличия от прежней версии (см. README_FIX.md):
///  - пароль больше не уходит на oauth.vk.ru с grant_type=password — используется
///    api.vk.ru/oauth/token c phone_confirmation_sid через сервис (m1.f.a);
///  - SMS/push/email реально отправляются через ecosystem.sendOtp* (m1.f.f);
///  - «Отправить повторно» работает;
///  - выбор методов парсит response.methods[] (B_RunnableC0023l0.java:127);
///  - капча (error 14 / need_captcha) показывается и вводится, а не «блокирует»;
///  - checkOtp передаёт verification_method; при access_token в ответе сразу пост-логин;
///  - need_validation из oauth/token автоматически отправляет OTP нужным каналом.
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
  final _captchaCtrl = TextEditingController();
  String _title = 'Вход в VK';
  String _info = '';
  bool _loading = false;
  VkLkmpCaptcha? _captcha;
  List<VkLkmpVerificationMethod> _methods = [];
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
    _captchaCtrl.dispose();
    _http.close();
    super.dispose();
  }

  // ------------------------------------------------------------------ helpers

  void _clearCaptcha() {
    _captcha = null;
    _captchaCtrl.clear();
  }

  String _short(Object o) {
    final s = o.toString();
    return s.length > 220 ? '${s.substring(0, 220)}…' : s;
  }

  void _handleAuthError(VkLkmpAuthException e) {
    setState(() {
      if (e.kind == 'captcha' && e.captcha != null) {
        _captcha = e.captcha;
        _info = 'Введите код с картинки';
      } else if (e.kind == 'flood') {
        _info = 'Слишком много попыток. Подождите 2–3 минуты и попробуйте снова.';
      } else {
        _info = e.message;
      }
    });
  }

  void _showPassword() {
    setState(() {
      _step = _Step.password;
      _title = 'Введите пароль';
      _info = '';
      _passCtrl.clear();
    });
  }

  void _showCode(String method, String info) {
    String title = 'Введите код из смс';
    if (method == 'push') title = 'Введите код из уведомления';
    if (method == 'email') title = 'Введите код из письма';
    if (method == 'reserve_code') title = 'Введите резервный код';
    if (method == 'codegen') title = 'Введите код';
    String hint = info;
    if (method == 'sms' && info.isNotEmpty) hint = 'На номер $info поступит SMS или звонок-сброс';
    if (method == 'push' && info.isNotEmpty) hint = 'Push отправлен на устройство $info';
    if (method == 'email' && info.isNotEmpty) hint = 'Письмо отправлено на $info';
    setState(() {
      _step = _Step.code;
      _title = title;
      _currentMethod = method;
      _currentInfo = info;
      _info = hint;
      _codeCtrl.clear();
    });
  }

  void _showMethods(List<VkLkmpVerificationMethod> methods) {
    setState(() {
      _methods = methods;
      _step = _Step.chooseMethod;
      _title = 'Выберите способ подтверждения';
      _info = '';
    });
  }

  void _finish() {
    widget.onSuccess?.call();
    if (mounted) Navigator.of(context).pop(true);
  }

  // ------------------------------------------------------------------- шаги

  Future<void> _doLogin() async {
    if (_loginCtrl.text.trim().length < 4) {
      setState(() => _info = 'Слишком короткий логин');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await _auth.validateAccount(
        phone: _loginCtrl.text.trim(),
        captcha: _captcha,
        captchaKey: _captchaCtrl.text.trim(),
      );
      _clearCaptcha();
      final resp = res['response'];
      String vm = '';
      String nsInfo = '';
      if (resp is Map && resp['next_step'] is Map) {
        final ns = resp['next_step'] as Map;
        vm = '${ns['verification_method'] ?? ''}';
        nsInfo = '${ns['info'] ?? ''}';
      }
      if (vm == 'password') {
        _showPassword();
        return;
      }
      if (vm == 'sms' || vm == 'push' || vm == 'email') {
        // как в LKMP: сами отправляем OTP (m1.f.f), иначе код не придёт
        final otp = await _auth.sendOtp(channel: vm);
        final r = otp['response'];
        final otpInfo = (r is Map && r['info'] != null && '${r['info']}'.isNotEmpty)
            ? '${r['info']}'
            : nsInfo;
        _showCode(vm, otpInfo);
        return;
      }
      if (vm == 'reserve_code' || vm == 'codegen') {
        _showCode(vm, nsInfo);
        return;
      }
      // нет next_step или неизвестный метод — запрашиваем список способов
      final methods = await _auth.getVerificationMethods();
      if (methods.isNotEmpty) {
        _showMethods(methods);
        return;
      }
      if (_auth.sid.isNotEmpty) {
        _showCode('sms', nsInfo);
        return;
      }
      setState(() => _info = 'Неизвестный ответ сервера: ${_short(res)}');
    } on VkLkmpAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      setState(() => _info = _short(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseMethod(String name, String info) async {
    if (name == 'password') {
      _showPassword();
      return;
    }
    if (name == 'reserve_code' || name == 'codegen') {
      _showCode(name, info);
      return;
    }
    setState(() => _loading = true);
    try {
      final otp = await _auth.sendOtp(channel: name);
      final r = otp['response'];
      final otpInfo = (r is Map && r['info'] != null && '${r['info']}'.isNotEmpty)
          ? '${r['info']}'
          : info;
      _showCode(name, otpInfo);
    } on VkLkmpAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      setState(() => _info = _short(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitCode() async {
    if (_codeCtrl.text.trim().isEmpty) {
      setState(() => _info = 'Введите код');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await _auth.checkOtp(
        code: _codeCtrl.text.trim(),
        verificationMethod: _currentMethod,
        captcha: _captcha,
        captchaKey: _captchaCtrl.text.trim(),
      );
      _clearCaptcha();
      final resp = res['response'];
      if (resp is Map && (resp['access_token'] != null || resp['token'] != null)) {
        // если VK сразу вернул токен — пост-логин, как в LKMP (m1.f.b)
        await _auth.postLogin(resp.cast<String, dynamic>());
        _finish();
        return;
      }
      // иначе — как в LKMP: экран пароля (grant_type=phone_confirmation_sid)
      _showPassword();
    } on VkLkmpAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      setState(() => _info = _short(e));
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
      final r = await _auth.loginWithPassword(
        password: _passCtrl.text,
        captcha: _captcha,
        captchaKey: _captchaCtrl.text.trim(),
      );
      _clearCaptcha();
      if (r.success) {
        _finish();
        return;
      }
      // need_validation: сервис уже отправил OTP нужным каналом
      _showCode(r.otpChannel, '');
    } on VkLkmpAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      setState(() => _info = _short(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    final channel = (_currentMethod == 'sms' || _currentMethod == 'push' || _currentMethod == 'email')
        ? _currentMethod
        : 'sms';
    setState(() => _loading = true);
    try {
      final otp = await _auth.sendOtp(channel: channel);
      final r = otp['response'];
      setState(() {
        _info = (r is Map && r['info'] != null && '${r['info']}'.isNotEmpty)
            ? 'Код отправлен повторно (${r['info']})'
            : 'Код отправлен повторно';
      });
    } on VkLkmpAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      setState(() => _info = _short(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131313),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131313),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(_step == _Step.login ? 'Вход' : 'Подтверждение',
            style: const TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 38),
          child: _buildStep(),
        ),
      ),
    );
  }

  Widget _captchaField() {
    return Column(
      children: [
        if (_captcha != null && _captcha!.img.isNotEmpty)
          Image.network(_captcha!.img, height: 60, fit: BoxFit.contain),
        const SizedBox(height: 8),
        TextField(
          controller: _captchaCtrl,
          style: const TextStyle(color: Color(0xFFC8C8C8), fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Код с картинки',
            hintStyle: const TextStyle(color: Color(0xFFD5D5D5)),
            filled: true,
            fillColor: const Color(0xFF1F1F1F),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _button({
    required String label,
    required VoidCallback? onPressed,
    Color color = const Color(0xFF0077FF),
  }) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        onPressed: onPressed,
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
    );
  }

  Widget _infoText({Color color = Colors.white, bool bold = true}) {
    if (_info.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        _info,
        style: TextStyle(
            color: color, fontSize: 14, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
        textAlign: TextAlign.center,
      ),
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFD5D5D5)),
        filled: true,
        fillColor: const Color(0xFF1F1F1F),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      );

  Widget _buildStep() {
    if (_step == _Step.chooseMethod) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Выберите способ подтверждения',
              style: TextStyle(color: Colors.white, fontSize: 18), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ..._methods.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _button(
                  label: _labelFor(m.name, m.info),
                  color: const Color(0xFF2D2D2D),
                  onPressed: _loading ? null : () => _chooseMethod(m.name, m.info),
                ),
              )),
        ],
      );
    }

    if (_step == _Step.code) {
      final canResend =
          _currentMethod == 'sms' || _currentMethod == 'push' || _currentMethod == 'email';
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_title,
              style: const TextStyle(color: Colors.white, fontSize: 18), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextField(
            controller: _codeCtrl,
            style: const TextStyle(color: Color(0xFFC8C8C8), fontSize: 16),
            decoration: _deco(_currentMethod == 'reserve_code' ? 'Резервный код' : 'Код'),
            keyboardType: TextInputType.number,
          ),
          if (_captcha != null) ...[const SizedBox(height: 12), _captchaField()],
          _infoText(),
          const SizedBox(height: 12),
          _button(label: 'Подтвердить', onPressed: _loading ? null : _submitCode),
          if (canResend) ...[
            const SizedBox(height: 8),
            _button(
              label: 'Отправить код повторно',
              color: const Color(0xFF2D2D2D),
              onPressed: _loading ? null : _resend,
            ),
          ],
        ],
      );
    }

    if (_step == _Step.password) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Введите пароль',
              style: TextStyle(color: Colors.white, fontSize: 18), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl,
            obscureText: true,
            style: const TextStyle(color: Color(0xFFC8C8C8), fontSize: 16),
            decoration: _deco('Пароль'),
          ),
          if (_captcha != null) ...[const SizedBox(height: 12), _captchaField()],
          _infoText(color: Colors.white, bold: false),
          const SizedBox(height: 12),
          _button(label: 'Войти', onPressed: _loading ? null : _submitPassword),
        ],
      );
    }

    // login
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Вход в VK',
            style: TextStyle(color: Colors.white, fontSize: 18), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        TextField(
          controller: _loginCtrl,
          style: const TextStyle(color: Color(0xFFC8C8C8), fontSize: 16),
          decoration: _deco('Телефон или почта'),
          keyboardType: TextInputType.emailAddress,
        ),
        if (_captcha != null) ...[const SizedBox(height: 12), _captchaField()],
        _infoText(color: const Color(0xFFFF5252)),
        const SizedBox(height: 12),
        _button(label: 'Далее', onPressed: _loading ? null : _doLogin),
      ],
    );
  }

  String _labelFor(String method, String info) {
    if (method == 'sms') return 'Номер телефона $info';
    if (method == 'push') return 'Уведомление на устройство $info';
    if (method == 'email') return 'Электронная почта $info';
    if (method == 'password') return 'Ввести пароль';
    if (method == 'reserve_code') return 'Ввести резервный код';
    if (method == 'codegen') return 'Приложение для генерации кодов';
    return info.isNotEmpty ? '$method — $info' : method;
  }
}
