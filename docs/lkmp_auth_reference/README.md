# LKMP 34 (2.0.2) — полный код авторизации ВКонтакте (разбор из APK)

Источник: `LKMP_34_2.0.2.apk` (декомпиляция jadx 1.4.7, R8-обфускация). Все имена классов
оставлены 1:1 как в APK (`N1/e`, `m1/f`, `w1/e` и т.д.) — файлы в `api/` и `ui/` скопированы
без изменений из полного дампа. Параллельно даются «читаемые» названия, восстановленные
из логики кода.

---

## 1. Общая архитектура

Авторизация разнесена на три слоя:

| Слой | Класс (как в APK) | Роль |
|---|---|---|
| **API** | `N1.e` (`api/N1_e.java`) | HTTP-клиент авторизации: аноним-токен, `ecosystem.*`, `oauth/token`, `oauth/auth_by_exchange_token`, общие заголовки, gzip, cookie |
| **Модуль** | `m1.f` (`api/m1_f.java`) | Логика входа: `auth.validateAccount`, `oauth/token` по паролю, отправка/проверка OTP, сохранение профиля и сессии, восстановление сессии |
| **UI** | `w1.e` = `C0589e` (`ui/w1_C0589e.java`) | Экран авторизации: надувает `route_auth.xml`, переключает слайды ввода (`T1.b` + `auth_steep_*.xml`), показывает капчу и список методов подтверждения |
| Состояние | `m1.C0448c` (AuthInfo), `M1.d` (audat: token/user_id/exchange_token/secret), `m1.g` (AuthRes), `m1.h` (Captcha), `m1.C0450e` (VerificationMethods), `m1.EnumC0446a` (экраны) | DTO и перечисления |
| Персист | `android.support.v4.media.session.q` — методы `R()/V()/S()` (jadx ошибочно положил класс приложения в пакет медиасессии; выдержка — `api/session_q_extract.java`) | SharedPreferences: токены, exchange_token, профиль |

Модуль создаётся при старте приложения: `c1/CallableC0241b.java`, case 2:
`main.f6872m = new m1.f(main3)` — далее `main3.s().c()` проверяет сохранённую сессию.

---

## 2. Константы (все захардкожены в коде)

```
client_id      = 2274003            # Android-приложение VK (официальный публичный client_id)
client_secret  = hHbZxrka2uZ6jB1inYsH
api_id         = 2274003
v              = 5.276              # версия API для всех запросов авторизации
sak_version    = 1.144.0
flow_type      = tg_flow            # в checkOtp/getVerificationMethods/oauth/token
               = auth_without_password  # в auth.validateAccount
lang           = ru
https          = 1
scope          = all                # в oauth/token и auth_by_exchange_token
host           = https://api.vk.ru  (не .com!)
```

Fallback-ветка `execute.getUserInfo` использует **другую** версию: `v=5.131`
(если `v` не задана явно в PostParams — см. `N1.e.h()`).

### User-Agent (A.b.x, выдержка — `api/A_b_extract.java`)

```
VKAndroidApp/8.175-51775 (Android <RELEASE>; SDK <SDK_INT>; <os.arch>; <Build.MODEL>; <lang>; <ширина>x<высота>)
```
При исключении — константа: `VKAndroidApp/8.87-21014 (Android 12; SDK 31; arm64-v8a;Google Nexus 5X; ru; 1920x1080)`.

### device_id (A.b.y)

```
device_id = android_id + ':' + MD5(Build.MODEL + Build.ID + Build.MANUFACTURER + Build.BRAND + Build.TYPE + os.arch)
```
Нюанс 1: MD5 считается без паддинга нулями (`Integer.toHexString(b & 255)` — без `%02x`),
поэтому хэш может быть короче 32 символов — это воспроизведено в `A.b.E` и так и должно быть.
Нюанс 2: значение кешируется в статике `N1.e.f2294n`. Нюанс 3: при сбое — константный
суффикс `:45c4c99f645eacee39036f5c4f8cddbf`.

### gaid (fake)

Не настоящий Advertising ID, а **случайный UUID**, сгенерированный локально из 32 hex-символов
(`8-4-4-4-12`, генератор `N1.e.g(int)`), сид — `System.currentTimeMillis()`, разбитый на два int:
`new f((int) t, (int) (t >> 32))`. Генерируется один раз на инстанс `N1.e`.

---

## 3. Общий конверт HTTP-запросов (N1.e.d)

```
POST https://api.vk.ru/method/<method>[<f2298d>]     # f2298d — суффикс к URL (по умолчанию "")
Content-Type: application/x-www-form-urlencoded; charset=utf-8
Cache-Control: no-cache
Accept: image/webp
Accept-Encoding: gzip
User-Agent: <A.b.x>
X-VK-Android-Client: new
X-Screen: <контекст экрана>          # auth | auth_start_with_phone | auth_password
<urlencoded тело PostParams>
```

- CookieManager с политикой `ACCEPT_ALL` подключён к клиенту (OkHttp-подобная самописная
  реализация в пакетах `N0.*`); cookie хранятся в `M1.a` (парсер Set-Cookie, поддержка
  удаления значением `DELETED`).
- Ответ при `Content-Encoding: gzip` распаковывается вручную.
- Результат — `N1.d (ApiRes)`: `error`, `json`, `code`, `cookie`, `rawRedirect` (`f2292e` —
  используется только в `oauth/auth_by_exchange_token`, см. ниже).
- Сетевые исключения → `ApiRes(error=true, json={})`.
- Повторные попытки: обёртка `N1.e.e()` даёт до **3 попыток**; при API-ошибке
  `error_code == 1117` (токен анонима истёк) — сначала `h()` (обновление exchange-токена),
  затем повтор запроса (максимум 3 раза).

Значения `X-Screen`:
- `auth_start_with_phone` → `auth.getAnonymToken`, `auth.validateAccount`
- `auth` → `ecosystem.*`
- `auth_password` → `oauth/token`, `oauth/auth_by_exchange_token`

---

## 4. Полный флоу входа «без пароля» (основной)

### Шаг 0. Экран (route_auth.xml, `skin/`)
Фон `#131313`, логотип 130dp (`img/logo`), кнопка «Музыка с телефона и радио»
(`notLogin_btn` — гостевой режим: `prefs("radio").guest=true`), скрытая кнопка
«Другой способ» (`another_confirm`), контейнер слайдов `content_block`,
скрытый слой обновления `updateLayer` (запрос `app.getUpdate` с `v=1.0`, `v_code=34`).

### Шаг 1. Ввод логина — слайд `auth_steep_enter_login.xml`
EditText `value` («Телефон или почта», `inputType=textEmailAddress`), блок капчи
(`captcha_block`: ImageView `captcha_image` + EditText `captcha_value`), поле ошибки
`info` (`#FF4141`), кнопка «Продолжить» (55dp, `#1E90FF`, radius 8, border `1px #6A605D5D`).

Сабмит (`ui/w1_C0588d.java`, case 1):
- валидация длины: `< 4` символов → «Слишком короткий логин»;
- если на слайде открыт капча-блок — в запрос добавляются `captcha_sid`, `captcha_key`,
  `captcha_attempt=1`, `captcha_ts`, `is_sound_captcha=0`;
- в фоне (`O1.a`, case 3): `m1.f.i(login, params)` → **`auth.validateAccount`**:

```
login                  = <введённое>
access_token           = <аноним-токен>            # см. Шаг 2
supported_ways         = push,email,sms,callreset,password,reserve_code,codegen,official_messenger,max_code,passkey,libverify,max_messenger
force_password         = 0
flow_type              = auth_without_password
sak_version, gaid, device_id, lang, v, https, api_id
```

**Аноним-токен** (`N1.e.b()`): `POST auth.getAnonymToken` c `client_id=2274003`,
`client_secret=hHbZxrka2uZ6jB1inYsH`, `device_id`, `lang=ru`, `v=5.276`, `https=1`,
`api_id=2274003`; из `response.token`. Ошибка → «Ошибка получения мохентокена» (так в коде).
`m1.f.c()` кеширует токен в `f6406a`.

- Ошибка `error_code == 14` → исключение `L1.a(Captcha)` → показ капчи (см. §8).
- Ответ: `response.sid` → AuthInfo.sid; `response.remember_hash` → AuthInfo.remember_hash;
  `next_step.verification_method` определяет следующий экран:

| verification_method | Действие | Экран (m1.EnumC0446a) |
|---|---|---|
| `sms` | `m1.f.f(25)` → `ecosystem.sendOtpSms` | SMS_CODE |
| `push` | `m1.f.f(27)` → `ecosystem.sendOtpPush` | PUSH |
| `email` | `m1.f.f(26)` → `ecosystem.sendOtpEmail` | EMAIL_CODE |
| `password` | слайд пароля | PASSWORD |
| `codegen` | слайд ввода кода из приложения-генератора | CODE_GEN |
| `reserve_code` | слайд ввода резервного кода | RESERVE_CODE |
| прочее | «ХЗ МЕТОД:...» (так в коде) | SELECT_ANOTHER |

- Если нет `next_step`, но `flow_name == need_registration` → исключение
  «Пользователь не зарегистрирован»; `need_password_and_validation` → экран пароля.

### Шаг 2. Отправка OTP (`m1.f.f(int)`)

```
sid            = <AuthInfo.sid>
access_token   = <аноним-токен>
lang, device_id, sak_version=1.144.0, flow_type=tg_flow, gaid, v=5.276, https=1, api_id=2274003
POST https://api.vk.ru/method/ecosystem.sendOtpSms|sendOtpPush|sendOtpEmail   (25/27/26)
```
Ответ: `response.sid` обновляет AuthInfo.sid; `response.info` — подпись под полем ввода.
Если `verification_method` не sms/email/push — текст «Метод X не поддерживается, но попробуйте».
Экраны подписей (`w1.C0589e.o`):
- sms: «Введите код из смс» / «На ваш номер <info> поступит SMS-сообщение с кодом или звонок-сброс»
- push: «Введите код из уведомления» / «Push-уведомление отправлено на ваше устройство <info>»
- email: «Введите код из письма» / «Письмо отправлено на почту <info>»
- codegen: «Введите код» / «Код создаётся в приложении для генерации кодов»
- reserve_code: «Введите резервный код» / «Один из одноразовых резервных кодов от вашего аккаунта VK ID»

### Шаг 3. Проверка кода — слайд `auth_steep_code.xml` (минимум 4 символа)

Сабмит (`ui/g1_RunnableC0313D.java`, case 1 → `N1.e.a()`):

```
sid                 = <AuthInfo.sid>
verification_method = <sms|email|push|codegen|reserve_code>
code                = <код>
access_token        = <аноним-токен>
lang, device_id, sak_version, flow_type=tg_flow, gaid, v, https, api_id
POST https://api.vk.ru/method/ecosystem.checkOtp
```

- Ошибка `error_code == 14` → капча; прочие ошибки — `error.error_text`.
- В ответе `response.can_skip_password` (→ AuthInfo.can_skip_password) и новый `sid`.
- Если в ответе сразу `access_token` → сразу пост-логин (Шаг 5).
- Иначе → экран пароля (`auth_steep_password.xml`): `inputType=textPassword`, минимум
  4 символа, та же капча-приставка в параметрах.

### Шаг 4. Вход по паролю (`m1.f.a(password, params)`)

```
sid                          = <AuthInfo.sid>
username                     = <логин с шага 1>
password                     = <пароль>
anonymous_token              = <аноним-токен>
libverify_support            = 1
scope                        = all
device_trusted_hash_supported= 1
grant_type                   = phone_confirmation_sid
2fa_supported                = 1
supported_ways               = push,email
lang, device_id, sak_version=1.144.0, flow_type=tg_flow, gaid, anonymous_token, v=5.276, https=1, api_id=2274003
POST https://api.vk.ru/oauth/token            (X-Screen: auth_password)
```

Обработка ошибок:
- `error == need_captcha` → исключение `L1.a` с полями `captcha_img`, `captcha_ratio`,
  `captcha_sid`, `captcha_ts`, `redirect_uri`;
- `error == need_validation` → 2FA-подтверждение: `validation_type` =
  `2fa_sms` → `f(25)`, `2fa_push` → `f(27)`, `2fa_email` → `f(26)`, `2fa_app` — экран FA_APP
  (в switch пусто — не поддерживается); прочее — текст `error_description`;
- `error == invalid_client` → `error_description`;
- успех: `access_token` → пост-логин (Шаг 5).

### Шаг 5. Пост-логин (`m1.f.b(JSONObject)`) — обязательно после получения access_token

1. `M1.d`: `token = access_token`, `user_id = user_id` из ответа.
2. `execute.getUserInfo` c `func_v=33`, `needExchangeToken=1` → `response.exchange_token`
   сохраняется в `M1.d.exchange_token`.
3. `auth.refreshToken` (`lang=ru`) — ответ не используется, но запрос обязателен.
4. `account.getProfileInfo` → профиль: `first_name`, `last_name`, `id`, `sex`,
   `photo_200`, `screen_name`, `bdate`, `city` → `"<id>_<title>"`, `country` → `"<id>_<title>"`.
5. Профиль пишется в SharedPreferences (ключи без изменений):
   `uc`=first_name, `ud`=last_name, `ur`=user id, `ux`=sex, `uf`=photo_200,
   `ue`=screen_name, `ua`=bdate, `ub`=city, `uy`=country.
6. Сессия сохраняется (`q.V`): `b`=access_token, `c`=user_id, `ex`=exchange_token.
7. Колбэк `AuthRes(SUCCESS)` закрывает авторизацию (`f7579j.b(true)`).

### Шаг 6. «Другой способ подтверждения» (кнопка `another_confirm` → `C0589e.s()`)

Фоновый поток (`B/RunnableC0023l0.b()`): `ecosystem.getVerificationMethods` c
`sid` и `access_token` (аноним). Ответ `response.methods[]`: `info`, `priority`,
`timeout`, `name`. Список рендерится в option-окно (`P1.t`), подписи:
- `sms` → «Номер телефона <info>»
- `push` → «Уведомление на устройство <info>»
- `email` → «Электронная почта <info>»
- `reserve_code` → «Ввести резервный код»
- `codegen` → «Приложение для генерации кодов»
- `password` → «Ввести пароль»
- прочее → «Непонятный метод-<name> - <info>»

Выбор пункта (`w1.C0586b.c`) повторяет таблицу §Шаг 1 (sms/push/email → `m1.f.g(25/26/27)`
с колбэком на новый экран; reserve_code/codegen — сразу слайд; password — слайд пароля).

---

## 5. Восстановление сессии и обновление токенов

### Восстановление (`m1.f.d()`)
`q.R(M1.d)` читает `b` (access_token), `c` (user_id), `ex` (exchange_token);
сессия считается валидной при непустых access_token **и** user_id. Затем профиль
подгружается из prefs (см. Шаг 5) и статистика `usa`/`usb`.

### Обновление при ошибке 1117 (`N1.e.h()`)
1. `POST oauth/auth_by_exchange_token` (X-Screen: `auth_password`):
   ```
   lang=ru, https=1, api_id=2274003, client_id=2274003, initiator=expired_token,
   gaid=<fake>, exchange_token=<сохранённый>, scope=all, device_id, v=5.276
   ```
   Ответ приходит **фрагментом URL**: строка вида `#access_token=...&...` — код режет по
   первому `#` и парсит `key=value` парами; `access_token` кладётся в `M1.d.token`.
2. Если ответ пуст — fallback через **нативный JNI** `VKMPLite.vMethod`
   (`libVKMPLite.so`, сигнатура: `(method, token, secret, params, UA, device_id, v)`):
   `execute.getUserInfo` c `needExchangeToken=1`, `func_v=30`, `device_id=<android_id без хэша>`,
   `v=5.131` (если не задана). Из `response.exchange_token` обновляется `M1.d.exchange_token`,
   сессия пересохраняется, и запрос повторяется.
3. Повтор запроса — до 3 попыток (обёртка `N1.e.e`).

### Выход (`q.S()`)
Чистит ключи `a, b, c, ua, ub, uc, ud, ue, uf, ur, ux, uy, session_uid` и флаг `user_send_data`.

---

## 6. Экраны (m1.EnumC0446a — значения по ordinal)

```
0 SUCCESS, 1 ERROR, 2 ENTER_LOGIN, 3 EMAIL_CODE, 4 PASSWORD, 5 PUSH, 6 RESERVE_CODE,
7 SMS_CODE, 8 CODE_GEN, 9 CAPTCHA, 10 SELECT_ANOTHER, 11 HZ («что-то странное»),
12 FA_SMS, 13 FA_APP, 14 FA_PHONE_MASK, 15 FA_REDIRECT, 16 FA_CAPTCHA
```
Значения 12–16 объявлены, но в `w1`-обработчиках используются не все (`2fa_app` в
switch пароля намеренно пуст — метод не поддержан).

---

## 7. Капча

- Триггеры: API-ошибка `error_code == 14` (`auth.validateAccount`, `ecosystem.checkOtp`)
  или `error == need_captcha` (`oauth/token`).
- Поля: `captcha_img` (URL), `captcha_ratio`, `captcha_sid`, `captcha_ts`, `redirect_uri`.
- Если `redirect_uri` непуст — открывается WebView-диалог (`S1.C0129i1`) с JS-мостом
  `AndroidBridge.VKCaptchaGetResult(result)` (`S1.C0126h1`) — это VK ID-редирект-капча.
- Обычная капча: картинка скачивается в `cacheDir/max_images/<captcha_sid>` и показывается
  в `captcha_image`; ввод — `captcha_value`.
- При следующем сабмите добавляются: `captcha_sid`, `captcha_key`, `captcha_attempt=1`,
  `captcha_ts`, `is_sound_captcha=0`.

---

## 8. UI-нюансы

- Слайды ввода кешируются в `HashMap` по имени и повторно используются; переключение —
  замена единственного ребёнка `content_block` (`T1.b.a(ViewGroup)`).
- Имена XML: `"auth_steep_" + name + ".xml"` (опечатка «steep» — так в оригинале);
  доступные: `enter_login`, `password`, `code`.
- Пароль: `setInputType(524417)` (textPassword+совет), логин: `524289` (textEmailAddress).
  В XML заданы `inputType="textPassword"` / `"textEmailAddress"` — дубль не мешает.
- Кнопка «Продолжить» блокируется (`button=FALSE`) на время запроса и разблокируется в
  колбэке; логотип скрывается (`J1.b.c()`) при отправке.
- Ошибки пишутся в `info` (`#FF4141`, textAlignment=center); текст «Неверный логин или
  пароль» зашит в XML как дефолт.
- Скелет-классы `w1.C0586b/C0587c/C0588d`, `g1.T`, `O1.a`, `B.RunnableC0023l0` —
  это R8-«склеенные» колбэки: нужные ветки описаны в комментариях выше, в файлах они
  идут под номерами case: `C0588d(1)=логин, (3)=пароль, (0)=список методов, (4)=update`,
  `C0587c(1)=сабмит кода, (2)=результат OTP/пароля, (0)=список методов`,
  `O1.a(3)=validateAccount, (4)=oauth/token, (1)=загрузка капчи`,
  `g1.T(7..13)=доставка результата в UI, (8/10/13)=капча из L1.a`,
  `RunnableC0023l0.b()=getVerificationMethods`.
- В коде есть опечатки/мусор, сохранённые 1:1: «мохентокен», «ХЗ МЕТОД», «next_steep»
  (в C0587c case 11 читается `next_steep.verification_method`), «Методы not fond»,
  «Что-то сломалось».

## 9. Скин-XML: сокращения атрибутов

Кастомный бинарный формат скина (распаковка — `tools/skin_unpack.py`,
декодер — `tools/skin_decode_xml.py`, формат описан в их шапках). Имена атрибутов
в скине сокращены; по контексту:
`^W`=layout_width, `^H`=layout_height, `^M`=match_parent, `^W`(значение)=wrap_content,
`^G`=gravity, `^P`=padding, `^LG`=layout_gravity, `^MB`=layout_marginBottom,
`^MT`=layout_marginTop, `^PS`=paddingStart, `^PE`=paddingEnd;
`^M` как значение гравитации = center. Виджеты `syxme.lkmp.skinner.c.designGroup`
(фон+radius+border) и `...designText` — кастомные из скин-системы (`B1.P`, инфлейтер
`q.P()` создаёт их рефлексией по имени).

---

## 10. Карта файлов

```
api/
  N1_e.java            — ЯДРО: HTTP-клиент авторизации (аноним-токен, checkOtp, методы, oauth, refresh)
  N1_a.java            — интерфейс колбэка ApiRes
  N1_b.java            — synthetic: generic API-вызов + retry 1117 (case 0)
  N1_c.java            — synthetic: фоновые колбэки (case 0 — обёртка e())
  N1_d.java            — ApiRes (error/json/code/cookie/rawRedirect)
  M1_a.java            — cookie-хранилище (Set-Cookie, DELETED)
  M1_b.java            — заголовки ответа
  M1_c.java            — пара name=value (используется и в PostParams, и в cookie)
  M1_d.java            — audat: token / user_id / exchange_token / secret (сессия)
  M1_e.java            — httpResponse (для нативного vMethod-пути)
  m1_f.java            — МОДУЛЬ АВТОРИЗАЦИИ (validateAccount, oauth/token, OTP, профиль, restore)
  m1_C0448c.java       — AuthInfo (sid/login/remember_hash/has_another_methods/method/can_skip_password)
  m1_EnumC0446a.java   — перечисление экранов
  m1_g.java            — AuthRes(error/text/code/out)
  m1_h.java            — Captcha(img/ratio/sid/ts/key/redirect_uri)
  m1_InterfaceC0449d.java — колбэк AuthRes
  m1_C0450e.java       — VerificationMethods(info/priority/timeout/name)
  L1_a.java            — исключение need_captcha
  PostParams.java      — упорядоченные form-параметры (pull() с URLEncoder)
  A_b_extract.java     — выдержка A.b: MD5(E), x (User-Agent), y (device_id) — 1:1
  session_q_extract.java — выдержка хранилища сессии: R/V/S (ключи b/c/ex) — 1:1
ui/
  w1_C0589e.java       — контроллер экрана авторизации (route_auth.xml)
  w1_C0586b.java       — выбор метода подтверждения
  w1_C0587c.java       — результаты логина/кода/пароля
  w1_C0588d.java       — сабмит логина/пароля + список методов + update
  T1_a.java, T1_b.java — слайд ввода (EditText+кнопка+info+капча)
  g1_RunnableC0313D.java — сабмит OTP → ecosystem.checkOtp
  g1_T.java            — диспетчер результатов в UI
  O1_a.java            — фоновые потоки логина/пароля + загрузка капчи
  B_RunnableC0023l0.java — поток getVerificationMethods
  S1_C0129i1.java      — WebView redirect_uri капчи (VK ID)
  S1_C0126h1.java      — JS-мост VKCaptchaGetResult
skin/
  route_auth.xml, auth_steep_enter_login.xml, auth_steep_password.xml,
  auth_steep_code.xml  — восстановленные из бинарного скина лейауты
tools/
  skin_unpack.py       — распаковка скина res/r7.dat (zlib-контейнер)
  skin_decode_xml.py   — декодер кастомного бинарного XML скина
```

## 11. Известные ограничения разбора

- `B.RunnableC0023l0.run()` (главный switch потоков) jadx не декомпилировал
  («Method not decompiled») — но приватный `b()` (getVerificationMethods) декомпилирован
  полностью, а вызовы восстановлены по конструкторам и колбэкам.
- Фабрика маршрутов, создающая `w1.e` на экране `route_auth`, и `j1.g` (базовый класс
  слайд-модулей) в пакет не включены — к протоколу авторизации они не относятся.
- `A.b.x()/y()` — статические методы гигантского утилит-класса `A.b`; в пакет включена
  выдержка `api/A_b_extract.java` (E/L/Q/x/y, код 1:1). Полный `A/b.java` есть в
  исходном дампе (`lkmp_decompiled_sources/A/b.java`).
- Методы персистенции `q.R/V/S` в оригинальном дампе лежат в
  `android/support/v4/media/session/q.java` (артефакт обфускации); в пакет включена
  выдержка `api/session_q_extract.java`.
