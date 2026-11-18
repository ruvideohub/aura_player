# AURA player — исправления авторизации VK (раунды 3–5)

Дата: 2026-11-18. Отладка выполнена **живыми запросами** к VK из песочницы
(скрипт `scripts/test_anon_token.py`), все выводы подтверждены ответами сервера.

# Раунд 5: капча на validateAccount и «капча не поддерживает картинку»

## Почему капча вообще появляется

`device_id` строился из **случайного** android_id и фейкового набора
«Google Nexus 5X», а UA был старой версии 8.87-21014. Для VK это устройство-инкогнито
с несогласованными признаками (android_id ≠ Build ≠ UA) — антифрод уводит такой
запрос в капчу (код 14) уже на `auth.validateAccount`, хотя реальное приложение
с реальной идентификацией капчу почти не получает.

## Что вернул живой разбор кода 14 (2026-11-18)

Ошибка 14 сегодня несёт **оба** варианта капчи:

| Поле | Значение в ответе |
|---|---|
| `captcha_img` | `https://vk.ru/captcha.php?sid=…&source=api_auth_validate_account_…&resized=1` — **настоящий PNG** (проверено: Content-Type image/png, 16 КБ) |
| `captcha_ratio` / `captcha_width` / `captcha_height` | 2.6 / размеры картинки |
| `redirect_uri` | `https://id.vk.ru/not_robot_captcha?domain=vk.com&session_token=…` — смарт-капча VK ID |
| `captcha_attempt`, `captcha_ts`, `is_sound_captcha_available`, `is_refresh_enabled` | служебные |

Повтор запроса без прохождения капчи → новая капча (новый sid) — это норма.
«Капча не поддерживает картинку» в приложении = картинка не отрисовалась
(нет UA/cookie при загрузке) либо пришёл вариант капчи только с `redirect_uri`
без `captcha_img` — старый UI не умел ни то, ни другое.

## Что сделано

1. **Реальная идентификация устройства** (главный фикс против капчи):
   - `MainActivity.kt` — новый метод канала `aura.player/native` → `deviceIdentity`:
     `android_id` (Settings.Secure) + `Build.MODEL/ID/MANUFACTURER/BRAND/TYPE/SUPPORTED_ABIS/VERSION`;
   - `vk_lkmp_auth.dart` — `device_id` теперь = реальный android_id + MD5 от реальных
     Build-полей (1:1 с A.b.y() эталона); фиктивный Nexus-идентификатор заменяется
     автоматически при первом же вызове;
   - UA динамический с реальными полями устройства, версия `8.175-51775` как в эталоне.
2. **`/method/*` = эталон 1:1** (m1/f.java:353): `v=5.276`, `sak_version=1.144.0`,
   полный `supported_ways` (12 способов: push,email,sms,callreset,password,
   reserve_code,codegen,official_messenger,max_code,passkey,libverify,max_messenger).
   oauth-слой не тронут (v=5.205, sak 1.123/1.104 — проверен живьём).
3. **Капча в UI** (`vk_lkmp_auth_page.dart`):
   - картинка грузится с хедерами клиента (`captchaImageHeaders()`: UA + cookie + Referer);
   - если картинки нет или она не загрузилась — кнопка **«Пройти проверку VK ID»**:
     `redirect_uri` открывается в WebView (`VkSmartCaptchaPage`), JS-мост перехватывает
     postMessage `vk-sak-sdk` с `success_token`/`captcha_key`, после «Готово» шаг
     повторяется автоматически с перехваченным токеном (если VK примет проверку
     серверно — повтор и без токена тоже предусмотрен).

## Что делать (раунд 5)

Заменить **три** файла (в архиве уже с правильной структурой):
- `lib/services/vk/vk_lkmp_auth.dart`
- `lib/ui/pages/vk_lkmp_auth_page.dart`
- `android/app/src/main/kotlin/com/example/aura_player/MainActivity.kt`

Пересобрать приложение. `flutter pub get` не нужен (новых зависимостей нет —
webview_flutter уже был в pubspec). SharedPreferences чистить не нужно: device_id
перегенерируется сам на реальный android_id.

Если капча всё же появится один раз после обновления (новый device_id для VK
«незнаком») — теперь её реально можно пройти: либо код с картинки, либо кнопкой
проверки VK ID. Дальше с устоявшейся идентификацией устройства капча должна
прекратиться.

# Раунд 4: ошибка 8 «versions below 5.81 are deprecated…» после ввода телефона

## Причина

В порте раунда 2 во **всех** вызовах `/method/*` (`auth.validateAccount`,
`ecosystem.sendOtp*`, `getVerificationMethods`, `checkOtp`) и в sid-ветке
`oauth/token` потерялся параметр `v` — в эталоне LKMP он есть в каждом
method-вызове (`v=5.276`). Без `v` VK отвечает:

```
{"error":{"error_code":8,"error_msg":"Invalid request",
 "descr":"version is required", ...}}
```

(на устройстве сообщение развёрнутое: «versions below 5.81 are deprecated…
"version" param is invalid» — это одна и та же ошибка 8).

## Проверено живьём (пробы G–J)

| # | Запрос | Ответ |
|---|--------|-------|
| G | `utils.getServerTime` **без v** | `error_code 8, "version is required"` — точное воспроизведение |
| H | то же с `v=5.205` | `{"response":1795031357}` — версия принимается |
| I | то же с `v=5.276` (эталон) | `{"response":…}` — тоже работает |
| J | `auth.validateAccount` с `v=5.205` | капча антифрода (код 14, для дата-центра), **не** ошибка 8 — проверка версии пройдена |

## Исправление

- `v=5.205` добавлен во все вызовы `/method/*` (validateAccount, sendOtpSms/Push/Email,
  getVerificationMethods, checkOtp) и в sid-ветку `oauth/token`
  (`grant_type=phone_confirmation_sid`). Проверка версии теперь проходит.

# Раунд 3: «Ошибка получения аноним-токена» до экрана входа

## Причина ошибки

Запрос получения аноним-токена **проходил успешно** — сервер возвращал валидный
токен, но код не находил его в ответе и бросал исключение:

```
POST https://api.vk.ru/oauth/get_anonym_token
(client_id=2274003, client_secret, lang, https, api_id, device_id, v=5.205)

Ответ VK (HTTP 200):
{"token": "anonym.eyJhbGciOiJIUzI1NiIs...", "expired_at": 1795116333}
```

Эндпоинт `/oauth/*` отвечает **плоским JSON** — токен лежит в корне `j['token']`,
обёртки `response` у него **нет**. Обёртка `{"response": {...}}` есть только у
`/method/*`-эндпоинтов. Прежняя версия читала только `j['response']['token']`,
получала `null` и падала с «Ошибка получения аноним-токена» ещё до экрана входа.

## Что исправлено в `lib/services/vk/vk_lkmp_auth.dart` (только этот файл)

1. `getAnonymToken()` теперь читает токен из плоского ответа `j['token']`,
   а `j['response']['token']` оставлен как запасной вариант (envelope).
2. Добавлен **fallback** на эталонный запрос референса LKMP (N1.e.b):
   `POST /method/auth.getAnonymToken` с `v=5.276` — если oauth-эндпоинт
   перестанет работать. Он тоже проверен живьём и возвращает токен.
3. Текст ошибки теперь содержит тело ответа VK (до 220 символов) — если сервер
   когда-нибудь вернёт что-то новое, это сразу будет видно в UI, а не
   безликое «ошибка получения».

## Результаты живой проверки (2026-11-18, все запросы — HTTP 200)

| # | Запрос | Ответ |
|---|--------|-------|
| A | `/oauth/get_anonym_token`, v=5.205, UA 8.87-21014 (как в коде) | **плоский** `{"token","expired_at"}` |
| B | `/oauth/get_anonym_token`, v=5.276 | плоский `{"token","expired_at"}` |
| C | `/method/auth.getAnonymToken`, v=5.276, UA 8.175-51775 (эталон LKMP) | `{"response":{"token","expired_at"}}` |
| D | `/method/auth.getAnonymToken`, v=5.205, UA 8.87 | `{"response":{"token","expired_at"}}` |
| E | то же на `api.vk.com` | `{"response":{"token","expired_at"}}` |
| F | `auth.validateAccount` с полученным токеном | `error_code 14 «Captcha needed»` — **это не ошибка токена**: значит токен принят API (невалидный токен дал бы ошибку 5/28). Капча — анти-фрод на запрос из дата-центра с тестовым номером; код капчу уже обрабатывает (экран капчи, kind=captcha) |

Примечание: прежнее утверждение «/method/auth.getAnonymToken отвечает ошибкой 9»
не подтвердилось — живой запрос возвращает токен. Ошибка 9 в исходной версии
была следствием другой проблемы, а не свойством эндпоинта.

## Что делать

1. Заменить в проекте один файл: `lib/services/vk/vk_lkmp_auth.dart`.
   Остальные файлы (`vk_api.dart`, `vk_account_manager.dart`,
   `vk_lkmp_auth_page.dart`) — без изменений, взяты из твоей текущей версии.
2. Пересобрать приложение. Чистить SharedPreferences **не нужно**:
   `vk_lkmp_device_id` и gaid не менялись и переиспользуются.
3. Дальше флоу прежний: телефон → validateAccount → код (sms/push/email) →
   oauth/token → пост-логин.

Если после этого шага VK покажет капчу или flood (ошибка 9) на конкретном
устройстве/сети — это уже штатная ветка флоу, UI её отрисует; при частом
повторении стоит проверить, не дребезжит ли device_id (сейчас он стабилен).
