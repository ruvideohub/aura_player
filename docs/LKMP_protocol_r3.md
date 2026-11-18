# LKMP: протокол авторизации VK (актуальная карта, 2026-11-18)

Сводка флоу `vk_lkmp_auth.dart` по референсу `LKMP_34_2.0.2.apk` (N1/e.java,
m1/f.java, A/b.java) с результатами живых проверок запросов. Всё, что помечено
«проверено живьём», подтверждено реальными ответами сервера в этот день.

## Константы

| Константа | Значение | Источник |
|---|---|---|
| client_id / api_id | `2274003` | N1/e.java (Android VK) |
| client_secret | `hHbZxrka2uZ6jB1inYsH` | N1/e.java |
| v | `5.205` (oauth-эндпоинты), `5.276` (все `/method/*` — как в эталоне) | libVKMPLite.so (0x4640/0x46a0) и референс |
| sak_version | `1.123` (oauth sid-флоу), `1.104` (password-grant, refresh), `1.144.0` (все `/method/*` — как в эталоне) | libVKMPLite.so (0x4710/0x4820) и m1/f.java |
| gaid | `236fd493-f8a3-4c52-97d4-acae50a72221` (захардкожен) | libVKMPLite.so |
| User-Agent | `VKAndroidApp/8.175-51775 (Android <RELEASE>; SDK <SDK>; <abi>; <MODEL>; ru; WxH)` — реальные поля устройства | A.b.x |
| Хост | `https://api.vk.ru` (не .com и не oauth.vk.ru; `api.vk.com` тоже работает — проверено живьём) | N1/e.java |

## device_id (A.b.y) — только реальные данные устройства

`android_id + ':' + MD5(Model + ID + Manufacturer + Brand + Type + abi)`,
где MD5 — с «багом» референса: hex-байты без ведущих нулей
(`Integer.toHexString(b & 0xFF)`), поэтому хэш может быть короче 32 символов.

С раунда 5 android_id берётся НАСТОЯЩИЙ (`Settings.Secure.ANDROID_ID` через
нативный канал `aura.player/native → deviceIdentity` в MainActivity.kt), и
Build-поля тоже реальные. Случайный android_id + фейковый Nexus 5X ловили
антифрод-капчу (код 14) на реальном телефоне — согласованная идентификация
снижает вероятность капчи. Fallback (не Android/сбой канала) — прежний
генератор Nexus 5X. Хранится в SharedPreferences (`vk_lkmp_device_id`).

Заголовки запроса (N1.e.d): `X-Screen: <экран>`, `Cache-Control: no-cache`,
`Accept: image/webp`, `User-Agent`, `X-VK-Android-Client: new`,
`Content-Type: application/x-www-form-urlencoded; charset=utf-8`.
`Accept-Encoding` вручную не ставить — dart:io добавляет gzip и сам распаковывает.

## Форматы ответов (критично!)

- `/method/*` — конверт API: успех `{"response": {...}}`, ошибка
  `{"error": {"error_code": N, "error_msg": "...", ...}}`. Коды:
  `9` flood, `14` капча.
- **Капча (код 14) — состав на 2026-11-18 (проверено живьём)**: внутри error
  приходят ОДНОВРЕМЕННО `captcha_img` (настоящий PNG на vk.ru/captcha.php,
  Content-Type image/png), `captcha_sid`, `captcha_ts`, `captcha_ratio/width/height`,
  `captcha_attempt`, `is_sound_captcha_available`, `is_refresh_enabled` и
  `redirect_uri` (`https://id.vk.ru/not_robot_captcha?domain=vk.com&session_token=…`
  — смарт-капча VK ID). Повтор запроса без прохождения → новая капча с новым sid.
  - Картинная капча: ретрай с `captcha_sid/captcha_key/captcha_attempt/captcha_ts/
    is_sound_captcha=0`; картинку грузить с UA/Cookie клиента.
  - Смарт-капча: страница VK ID по завершении шлёт postMessage `vk-sak-sdk` с
    `{captcha_sid, captcha_key:'', success_token}` — токен возвращается в форму,
    шаг повторяется с ним (или без него — если VK принял проверку серверно).
- `/oauth/*` — **плоский JSON без обёртки response** (проверено живьём):
  - `/oauth/get_anonym_token` → `{"token": "anonym.…", "expired_at": …}`
    (токен в корне! срок жизни 24 ч, в коде кеш 55 мин);
  - `/oauth/token` → `{"access_token": …}` или `{"error": "need_captcha" |
    "need_validation" | "invalid_client", "error_description": …}` — **строка в корне**;
  - `/oauth/auth_by_exchange_token` → 302, токен во ФРАГМЕНТЕ Location:
    `…#access_token=…&exchange_token=…&user_id=…`.
- Подпись sig через libVKMPLite в данном флоу не нужна: аноним-токен
  возвращается по client_secret без sig (проверено живьём 2026-11-18).

## Шаги флоу

1. **Аноним-токен** (N1.e.b): `POST /oauth/get_anonym_token`
   `client_id, client_secret, lang=ru, https=1, api_id, device_id, v=5.205`,
   screen `auth_start_with_phone`. Fallback: `POST /method/auth.getAnonymToken`
   с теми же полями и `v=5.276` — ответ в `response.token`. Оба проверены живьём.
2. **validateAccount** (m1.f.i): `POST /method/auth.validateAccount`
   `login, access_token=<anon>, supported_ways=push,email,sms,callreset,password,
   reserve_code,codegen,official_messenger,max_code,passkey,libverify,max_messenger,
   force_password=0, flow_type=auth_without_password, sak_version=1.144.0,
   gaid, device_id, lang, https, api_id, v=5.276`. Отвечает `sid`
   и/или `remember_hash`; при анти-фроде — капча (код 14).
3. **Отправка OTP** (m1.f.f): `POST /method/ecosystem.sendOtp{Sms,Push,Email}`
   `sid, access_token=<anon>, flow_type=tg_flow, sak_version=1.144.0, v=5.276, …`.
4. **Методы проверки** (N1.e.c): `POST /method/ecosystem.getVerificationMethods`
   → `response.methods[]` (name/info/priority/timeout).
5. **Проверка кода** (N1.e.a): `POST /method/ecosystem.checkOtp`
   `sid, verification_method, code, …` → `can_skip_password`.
6. **Токен по паролю** (m1.f.a): `POST /oauth/token`,
   `grant_type=password, sak_version=1.104, v=5.205, username, password,
   2fa_supported=1, supported_ways=push,email, scope=all, …`; по sid после OTP —
   `grant_type=phone_confirmation_sid, sid, anonymous_token, sak_version=1.123,
   v=5.205, flow_type=tg_flow, device_trusted_hash_supported=1`. При
   `need_validation` (2fa_*) — отправить OTP выбранным каналом и вести на код.
7. **Пост-логин** (m1.f.b): `execute.getUserInfo` (`func_v=33`,
   `needExchangeToken=1`) → `exchange_token`; `auth.refreshToken`;
   `account.getProfileInfo`. При `error_code 1117` — обмен exchange-токена
   (`/oauth/auth_by_exchange_token`, тело 0x4820: `lang=en, v=5.205,
   sak_version=1.104, initiator=expired_token, gaid const`) до 3 раз, ответ
   парсится из фрагмента `#access_token=…`.

## Замечания по анти-фроду и версиям

- **Каждый вызов `/method/*` обязан содержать `v`** (≥5.81; в коде `v=5.205`,
  проверено живьём: без `v` → `error_code 8, "version is required"`, с `v` —
  проходит; `v=5.276` из эталона тоже работает)./oauth/* на версию не ругается,
  но `v=5.205` там тоже передаётся (как в нативных телах).
- Запросы из дата-центров получают капчу (код 14) уже на validateAccount —
  это ожидаемое поведение VK, не признак сломанного токена.
- Cookie (`Set-Cookie`, напр. `remixstid`) сохраняются и отправляются дальше
  (порт CookieManager(ACCEPT_ALL)); значения `DELETED` удаляют cookie.
- Сетевые сбои ретраятся до 3 раз (N1.e.e); пустой ответ/не-JSON — ошибка сети/api.
