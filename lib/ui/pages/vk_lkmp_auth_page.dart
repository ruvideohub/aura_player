import 'dart:async' show Timer;
import 'dart:convert' show jsonDecode;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
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
///    картинка грузится с хедерами клиента, при пустой картинке/ошибке загрузки —
///    смарт-капча VK ID (redirect_uri) в WebView с авто-ретраем после прохождения;
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
  // Смарт-капча VK ID: success_token/captcha_key, перехваченные в WebView.
  String _smartToken = '';
  // Какой шаг повторить после прохождения капчи.
  VoidCallback? _retryAfterCaptcha;
  // Хедеры для загрузки captcha_img (кеш, чтобы Image не перезапрашивался).
  Future<Map<String, String>>? _captchaHeadersFuture;

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
    _smartToken = '';
  }

  /// Ключ капчи: смарт-капча (success_token) приоритетнее кода с картинки.
  String get _captchaKey => _smartToken.isNotEmpty ? _smartToken : _captchaCtrl.text.trim();

  /// Одноразовый авто-повтор без captcha-параметров после непринятого токена.
  bool _plainRetryPending = false;

  String _short(Object o) {
    final s = o.toString();
    return s.length > 220 ? '${s.substring(0, 220)}…' : s;
  }

  void _handleAuthError(VkLkmpAuthException e) {
    setState(() {
      if (e.kind == 'captcha' && e.captcha != null) {
        _captcha = e.captcha;
        _smartToken = ''; // новая капча — прежний success_token больше не действует
        _info = 'VK требует проверку. Для этого флоу картинка капчи не содержит '
            'кода (заглушка «не поддерживается») — пройдите проверку VK ID '
            'кнопкой ниже: она заменяет ввод кода.';
        if (_plainRetryPending) {
          // Токен не принят — автоматический чистый повтор (привязка сессии).
          _plainRetryPending = false;
          Future.microtask(() => _retryAfterCaptcha?.call());
        }
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
    _retryAfterCaptcha = _doLogin;
    try {
      final res = await _auth.validateAccount(
        phone: _loginCtrl.text.trim(),
        captcha: _captcha,
        captchaKey: _captchaKey,
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
    _retryAfterCaptcha = () => _chooseMethod(name, info);
    try {
      final otp = await _auth.sendOtp(
        channel: name,
        captcha: _captcha,
        captchaKey: _captchaKey,
      );
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
    _retryAfterCaptcha = _submitCode;
    try {
      final res = await _auth.checkOtp(
        code: _codeCtrl.text.trim(),
        verificationMethod: _currentMethod,
        captcha: _captcha,
        captchaKey: _captchaKey,
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
    _retryAfterCaptcha = _submitPassword;
    try {
      final r = await _auth.loginWithPassword(
        password: _passCtrl.text,
        captcha: _captcha,
        captchaKey: _captchaKey,
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
    final c = _captcha!;
    return Column(
      children: [
        if (c.img.isNotEmpty)
          FutureBuilder<Map<String, String>>(
            future: _captchaHeadersFuture ??= _auth.captchaImageHeaders(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox(
                    height: 60,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
              }
              return Image.network(
                c.img,
                height: 60,
                fit: BoxFit.contain,
                headers: snap.data,
                errorBuilder: (_, __, ___) => _smartCaptchaButton(
                    'Картинка капчи не загрузилась — пройдите проверку VK ID'),
              );
            },
          )
        else ...[
          const Text('VK просит подтвердить, что вы не робот',
              style: TextStyle(color: Color(0xFFC8C8C8), fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          _smartCaptchaButton(''),
        ],
        if (c.img.isNotEmpty) ...[
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
          const SizedBox(height: 8),
          const Text(
              'Если на картинке текст «Картинка не поддерживается» — кода здесь нет. '
              'Пройдите проверку VK ID: она заменяет ввод кода.',
              style: TextStyle(color: Color(0xFF8A8A8A), fontSize: 12),
              textAlign: TextAlign.center),
          _smartCaptchaButton(''),
        ],
      ],
    );
  }

  Widget _smartCaptchaButton(String note) {
    return Column(
      children: [
        if (note.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(note,
              style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 12),
              textAlign: TextAlign.center),
        ],
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF0077FF)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _loading ? null : _openSmartCaptcha,
            child: const Text('Пройти проверку VK ID («Я не робот»)',
                style: TextStyle(color: Color(0xFF0077FF), fontSize: 14)),
          ),
        ),
      ],
    );
  }

  /// Смарт-капча VK ID: открываем redirect_uri в WebView. Страница после
  /// успешной проверки вызывает AndroidBridge.VKCaptchaGetResult('{"token":…}')
  /// (мост настоящего VK SDK — инжектим свой) и/или редиректит на
  /// redirect+"?success_token=…" / oauth.vk.com/blank.html?success=1.
  /// Перехватываем токен и АВТОМАТИЧЕСКИ повторяем шаг, на котором пришла капча.
  Future<void> _openSmartCaptcha() async {
    final c = _captcha;
    if (c == null || c.redirectUri.isEmpty) {
      setState(() {
        _info = 'Смарт-капча недоступна (нет ссылки). Повторите запрос — VK пришлёт капчу заново.';
      });
      return;
    }
    final token = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => VkSmartCaptchaPage(url: c.redirectUri)),
    );
    if (!mounted) return;
    if (token != null && token.isNotEmpty && token != 'SUCCESS' && token != 'EXTERNAL') {
      setState(() {
        _smartToken = token;
        // Если VK не примет токен и вернёт капчу снова — один чистый повтор
        // без captcha-параметров (привязка решённой сессии на сервере).
        _plainRetryPending = true;
        _info = 'Проверка пройдена — повторяем запрос…';
      });
      _retryAfterCaptcha?.call();
    } else if (token == 'SUCCESS' || token == 'EXTERNAL') {
      // Проверка пройдена, но success_token не дошёл (страница ушла на
      // blank.html?success=1 или проверка была во внешнем браузере).
      // Сессия капчи решена на сервере — пробуем ЧИСТЫЙ повтор без captcha_key.
      setState(() {
        _smartToken = '';
        _info = 'Проверка пройдена — повторяем запрос…';
      });
      _retryAfterCaptcha?.call();
    } else {
      setState(() {
        _info = 'Если проверка пройдена — просто нажмите «Далее»/«Подтвердить» ещё раз';
      });
    }
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

/// WebView со смарт-капчей VK ID (redirect_uri из ошибки 14 / need_captcha).
/// Контракт страницы not_robot_captcha: детектит window.AndroidBridge
/// (мост настоящего VK SDK) — при его наличии снимается 8-секундный дедлайн
/// PoW, а по успеху вызывается AndroidBridge.VKCaptchaGetResult('{"token":…}');
/// параллельно страница может редиректить на redirect+"?success_token=…"
/// или oauth.vk.com/blank.html?success=1. Все три канала перехватываются,
/// токен возвращается в форму авторизации для авто-повтора запроса.
class VkSmartCaptchaPage extends StatefulWidget {
  final String url;
  const VkSmartCaptchaPage({super.key, required this.url});
  @override
  State<VkSmartCaptchaPage> createState() => _VkSmartCaptchaPageState();
}

class _VkSmartCaptchaPageState extends State<VkSmartCaptchaPage> {
  String _captured = '';
  String _status = 'Пройдите проверку «Я не робот» — дальше всё произойдёт само';
  Timer? _poll;
  bool _popped = false;
  bool _external = false; // ПК (нет webview) — открываем системный браузер

  /// Мост настоящего VK SDK: страница not_robot_captcha в начале JS-бандла
  /// запоминает window.AndroidBridge (isMobileSDK() → true) и по успеху вызывает
  /// AndroidBridge.VKCaptchaGetResult('{"token":"…"}'). Наличие моста снимает
  /// 8-секундный дедлайн проверки (PoW) и доставляет success_token напрямую.
  /// Инжектится в onPageStarted — до выполнения внешних скриптов страницы.
  static const _bridgeJs = '''
(function(){
  if (window.__auraBridge) return; window.__auraBridge = 1;
  var push = function(name, data){
    var s = name + ':' + (typeof data === 'string' ? data : JSON.stringify(data));
    try { window.__auraCaptchaResult = s; } catch(e) {}
    try { AuraCaptcha.postMessage(s); } catch(e) {}
  };
  var b = {};
  var names = ['VKCaptchaGetResult','VKCaptchaCloseCaptcha','VKCaptchaUserClose',
               'VKCaptchaListenSensorsStart','VKCaptchaListenSensorsChanged',
               'VKCaptchaListenSensorsWebChanged','VKCaptchaListenSensorsStop'];
  for (var i = 0; i < names.length; i++) (function(n){ b[n] = function(d){ push(n, d); }; })(names[i]);
  try { window.AndroidBridge = b; } catch(e) {}
})();
''';

  /// Страховка: заворачиваем postMessage (страница шлёт результат родителю,
  /// если считает себя встроенной) и слушаем входящие message-события.
  static const _hookJs = '''
(function(){
  if (window.__auraHook) return; window.__auraHook = 1;
  var send = function(d){ try { AuraCaptcha.postMessage(typeof d === 'string' ? d : JSON.stringify(d)); } catch(e){} };
  var wrap = function(w){ if(!w || w.__auraWrapped) return; try { w.__auraWrapped = 1; var o = w.postMessage.bind(w); w.postMessage = function(m,t){ send(m); return o(m,t); }; } catch(e){} };
  try { wrap(window.parent); wrap(window); } catch(e){}
  try { window.addEventListener('message', function(e){ send(e.data); }); } catch(e){}
})();
''';

  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..addJavaScriptChannel('AuraCaptcha', onMessageReceived: _onMessage)
    ..setNavigationDelegate(NavigationDelegate(
      onPageStarted: (url) {
        // Ранняя инжекция моста: внешние бандлы страницы ещё не исполнились.
        try {
          _controller.runJavaScript(_bridgeJs);
        } catch (_) {}
      },
      onPageFinished: (_) => _afterLoad(),
      onNavigationRequest: (r) {
        // Редирект после успеха: redirect_uri + "?success_token=…" либо
        // https://oauth.vk.com/blank.html?success=1. Ничего не блокируем!
        final t = _extractFromUrl(r.url);
        if (t != null && t.isNotEmpty && t != _captured) {
          if (t == 'SUCCESS') {
            _popWith('', 'Проверка пройдена — возвращаемся…');
          } else {
            _popWith(t, 'Проверка пройдена — возвращаемся…');
          }
        }
        return NavigationDecision.navigate;
      },
    ));

  @override
  void initState() {
    super.initState();
    final mobile = Platform.isAndroid || Platform.isIOS;
    if (!mobile) {
      _external = true;
      return;
    }
    try {
      _controller.loadRequest(Uri.parse(widget.url));
    } catch (_) {
      _external = true;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _afterLoad() {
    try {
      // onPageStarted мог не успеть до бандла — дублируем (защита __auraBridge).
      _controller.runJavaScript(_bridgeJs);
      _controller.runJavaScript(_hookJs);
    } catch (_) {}
    _poll ??= Timer.periodic(const Duration(milliseconds: 700), (_) => _pollTick());
  }

  /// Опрос: __auraCaptchaResult (мост/postMessage) + текущий URL (редирект
  /// с success_token / blank.html?success=1 виден даже без навигации).
  Future<void> _pollTick() async {
    if (_popped) return;
    try {
      final res = await _controller.runJavaScriptReturningResult(
          "(window.__auraCaptchaResult||'')+'|'+String(window.location.href)");
      final s = _cleanJs(res);
      final i = s.indexOf('|');
      final payload = i >= 0 ? s.substring(0, i) : s;
      final href = i >= 0 ? s.substring(i + 1) : '';
      final fromUrl = _extractFromUrl(href);
      if (fromUrl == 'SUCCESS') {
        _popWith('', 'Проверка пройдена — возвращаемся…');
        return;
      }
      final t = _tokenFromPayload(payload) ?? fromUrl;
      if (t != null && t.isNotEmpty && t != _captured) {
        _popWith(t, 'Проверка пройдена — возвращаемся…');
      }
    } catch (_) {}
  }

  String _cleanJs(Object res) {
    var s = '$res';
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      try {
        s = '${jsonDecode(s)}';
      } catch (_) {}
    }
    return s.replaceAll(r'\"', '"');
  }

  /// 'VKCaptchaGetResult:{"token":"…"}' или конверт
  /// '{"message":{"handler":"VKCaptchaGetResult","params":{"token":"…"}}}' → токен.
  String? _tokenFromPayload(String s) {
    if (s.isEmpty) return null;
    if (s.startsWith('VKCaptchaGetResult:') ||
        s.contains('"handler":"VKCaptchaGetResult"') ||
        s.contains('"handler": "VKCaptchaGetResult"')) {
      final m = RegExp(r'"token"\s*:\s*"([^"]+)"').firstMatch(s);
      if (m != null && m.group(1)!.isNotEmpty) return m.group(1);
    }
    for (final pat in [
      RegExp(r'"success_token"\s*:\s*"([^"]+)"'),
      RegExp(r'"captcha_key"\s*:\s*"([^"]+)"'),
    ]) {
      final m = pat.firstMatch(s);
      final v = m?.group(1);
      if (v != null && v.isNotEmpty && v != 'success') return v;
    }
    return null;
  }

  void _onMessage(JavaScriptMessage m) {
    if (_popped) return;
    final t = _tokenFromPayload(m.message);
    if (t == null || t.isEmpty || t == _captured) return;
    _popWith(t, 'Проверка пройдена — возвращаемся…');
  }

  void _popWith(String token, String status) {
    if (_popped || !mounted) return;
    _popped = true;
    _captured = token;
    _poll?.cancel();
    setState(() => _status = status);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) Navigator.pop(context, token.isEmpty ? 'SUCCESS' : token);
    });
  }

  String? _extractFromUrl(String url) {
    try {
      if (url.contains('blank.html') && url.contains('success=1')) return 'SUCCESS';
      final u = Uri.parse(url);
      for (final k in const ['success_token', 'captcha_key']) {
        final q = u.queryParameters[k];
        if (q != null && q.isNotEmpty) return q;
        final f = u.fragment.isNotEmpty ? _frag(u.fragment, k) : null;
        if (f != null && f.isNotEmpty) return f;
      }
    } catch (_) {}
    return null;
  }

  String? _frag(String frag, String key) {
    for (final p in frag.split('&')) {
      final i = p.indexOf('=');
      if (i > 0 && p.substring(0, i) == key) return Uri.decodeComponent(p.substring(i + 1));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_external) {
      // Windows/Linux/macOS: webview_flutter не поддерживается (белый экран в
      // прежних версиях) — открываем проверку в системном браузере. Сессия
      // капчи решается на сервере VK, поэтому после прохождения достаточно
      // чистого повтора запроса.
      return Scaffold(
        backgroundColor: const Color(0xFF131313),
        appBar: AppBar(
          backgroundColor: const Color(0xFF131313),
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Подтверждение VK ID', style: TextStyle(color: Colors.white)),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Проверка «Я не робот»',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text(
                  'Нажмите «Открыть браузер», пройдите проверку VK ID, затем '
                  'вернитесь в приложение и нажмите «Готово».',
                  style: TextStyle(color: Color(0xFFC8C8C8), fontSize: 14),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              _extButton('Открыть браузер', const Color(0xFF0077FF), _launchExternal),
              const SizedBox(height: 8),
              _extButton('Готово — я прошёл проверку', const Color(0xFF2D2D2D),
                  () => Navigator.pop(context, 'EXTERNAL')),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF131313),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131313),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Подтверждение VK ID', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _captured),
            child: const Text('Готово',
                style: TextStyle(color: Color(0xFF0077FF), fontSize: 16)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: WebViewWidget(controller: _controller)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_status,
                style: const TextStyle(color: Color(0xFFC8C8C8), fontSize: 13),
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _extButton(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
      ),
    );
  }

  Future<void> _launchExternal() async {
    try {
      await launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication);
    } catch (_) {
      setState(() => _status = 'Не удалось открыть браузер');
    }
  }
}
