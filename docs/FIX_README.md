# Фикс авторизации VK в aura_player (LKMP-флоу)

## Почему VK «блокировал» запросы

Логика была скопирована не полностью и местами неверно. Ниже каждое отклонение от эталона
(`docs/lkmp_auth_reference/` — разбор LKMP_34_2.0.2.apk) и чем оно аукалось. Ссылки вида
`N1_e.java:171` — на файлы эталонного пакета.

| # | Было в aura_player | Как в LKMP (эталон) | Симптом |
|---|---|---|---|
| 1 | Пароль: `POST https://oauth.vk.ru/token`, `grant_type=password` (`vk_lkmp_auth_page.dart:_submitPassword`) | `POST https://api.vk.ru/oauth/token`, `grant_type=phone_confirmation_sid` + `sid`, `anonymous_token`, `libverify_support=1`, `device_trusted_hash_supported=1`, `supported_ways=push,email` (`m1_f.java:80-103`) | VK отклоняет password-grant для новых входов; `sid` из validateAccount/checkOtp вообще не передавался |
| 2 | Пароль-запрос шёл «голым» `http.post` без заголовков — наружу уходил `User-Agent: Dart/x.x (dart:io)` | `X-Screen: auth_password`, `User-Agent: VKAndroidApp/8.175-51775 (…Google Nexus 5X…)`, `X-VK-Android-Client: new`, `Cache-Control`, `Accept: image/webp` (`N1_e.java:171-180`) | VK-антифрад режет запросы без клиентских заголовков — это и есть «блокировка» |
| 3 | `ecosystem.sendOtpSms/Push/Email` отсутствовали вовсе, кнопка «Отправить повторно СМС» — пустая `onPressed: () {}` | после `validateAccount` метод отправляется явно (`m1_f.java:289-303`) | SMS/push/email не приходят никогда — выглядит как «VK заблокировал» |
| 4 | `checkOtp` без `verification_method` | параметр обязателен (`g1_RunnableC0313D.java:124`) | VK отклоняет проверку кода |
| 5 | `getVerificationMethods` парсил `response.verification_methods` | `response.methods[]` с полями `info/priority/timeout/name` (`B_RunnableC0023l0.java:127`, `m1_C0450e.java`) | список методов всегда пустой, тупик |
| 6 | Cookie-хранилища не было | `CookieManager` с политикой `ACCEPT_ALL` подключён к клиенту (`N1_e.java:96-98`) | каждый запрос для VK — «новый клиент»: чаще капча и флуд-бан |
| 7 | Капча не обрабатывалась (`error_code 14`, `need_captcha`) | капча показывается, при следующем сабмите добавляются `captcha_sid/key/attempt=1/captcha_ts/is_sound_captcha=0` (`README §7`) | любое требование капчи выглядело как «заблокировали» |
| 8 | Ручной заголовок `Accept-Encoding: gzip` без ручной распаковки | LKMP декомпрессирует сам; в Dart это делает `dart:io` — если ставить заголовок руками, тело может прийти нераспакованным | `jsonDecode` падал на каждом ответе (FormatException) |
| 9 | Пост-логина не было: `execute.getUserInfo` (`func_v=33`, `needExchangeToken=1`) → `exchange_token`, `auth.refreshToken`, `account.getProfileInfo` не вызывались | обязательный шаг 5 (`m1_f.java:145-200`) | нет `exchange_token` → обновление токенов невозможно, сессия одноразовая |
| 10 | `refreshByExchangeToken` парсил JSON | ответ приходит **фрагментом URL** `#access_token=…&…`, код режет по первому `#` (`N1_e.java:346-356`) | refresh всегда возвращал null |
| 11 | Нет ретраев | 3 сетевые попытки (`N1.e.e`) и до 3 повторов при `error_code 1117` с обменом exchange-токена (`N1_b.java`, case 0) | любой сетевой сбой = фатальная ошибка |
| 12 | `need_validation` из oauth/token обрабатывался «вслепую» (`_showCodeFor('sms')` без отправки OTP) | `2fa_sms/push/email` → сразу `sendOtpSms/Push/Email` (`m1_f.java:110-130`) | код 2FA не отправлялся |

Главные причины «блокировки» — пункты **1, 2** (парольный запрос вообще не из протокола LKMP
и без VK-заголовков) и **5, 7** (капча/методы не обрабатывались, так что любой запрос
антифрода выглядел как «VK заблокировал»).

## Что исправлено

- `vk_lkmp_auth.dart` — полная замена сервиса. Это 1:1 порт `N1.e` + `m1.f`:
  - все запросы на `https://api.vk.ru` с правильным конвертом (UA/X-Screen/X-VK-Android-Client/cookie);
  - `oauth/token` c `grant_type=phone_confirmation_sid`;
  - `sendOtp*`, `checkOtp` c `verification_method`, `getVerificationMethods` → `response.methods[]`;
  - cookie-хранилище (аналог CookieManager/ACCEPT_ALL, удаление по значению `DELETED`);
  - пост-логин с получением `exchange_token` и профилем;
  - `refreshByExchangeToken` с парсингом `#access_token=…` (запрос без следования редиректам);
  - типизированные ошибки: `flood` / `captcha` / `invalid_client` / `need_validation` / `api` / `network`;
  - ретраи (3 сетевые попытки; до 3 повторов при 1117).
  Ключи SharedPreferences не изменились (`vk_music_token`, `vk_music_uid`, `vk_exchange_token`,
  `vk_lkmp_device_id`, `vk_lkmp_gaid`) — остальной код приложения совместим.
- `vk_lkmp_auth_page.dart` — страница под новый сервис: капча-блок на всех слайдах,
  рабочая кнопка «Отправить код повторно», пароль через сервис, автосообщение OTP при
  `need_validation`, пост-логин при токене в ответе `checkOtp`.

## Как применить

1. Заменить `lib/services/vk/vk_lkmp_auth.dart` файлом из этого архива.
2. Заменить `lib/ui/pages/vk_lkmp_auth_page.dart` файлом из этого архива.
3. Пересобрать приложение.

## Как проверять

- Перед первым тестом почистить старое состояние: удалить ключи `vk_lkmp_device_id` и
  `vk_lkmp_gaid` из SharedPreferences (или переустановить приложение).
- Не спамить запросами при отладке: `error 9` (Flood control) — нормальное поведение VK,
  у LKMP ровно тот же код ошибки; подождите 2–3 минуты.
- Ожидаемый флоу: логин → «код из смс» (SMS реально приходит) → пароль (если нужен) → вход.
  Если VK показывает капчу — теперь появится картинка и поле ввода.

## Известные ограничения

- Капча через `redirect_uri` (VK ID-редирект-капча, `S1.C0129i1` в эталоне) требует WebView —
  здесь обрабатывается только обычная картинка; при redirect-капче будет показан текст ошибки.
- gaid и device_id генерируются локально (как fallback в самом LKMP) — VK не может их
  проверить, но если аккаунт «жёстко» привязан к другому устройству, VK может попросить
  дополнительное подтверждение входа.
- Нативный JNI-fallback через `libVKMPLite.so` (N1.e.h шаг 2) не переносился — он нужен
  только когда exchange-токена нет совсем.
