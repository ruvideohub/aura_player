# Разбор libVKMPLite.so — что нашлось и что исправлено

Дата: 2026-11-18. Реверс `LKMP_34_2.0.2.apk` (x86_64-вариант библиотеки, NDK r29, stripped).

## Как устроена защита и «маринование» (кратко)

1. `VKMPLite.getPackageName()` (Java) возвращает `com.vkontakte.android`, если вызов пришёл
   из `org.chromium.base.BuildInfo` — WebView/Chromium считает приложение официальным клиентом.
2. `initLibrary()` (нативно):
   - читает hex-строку сертификата подписи APK (`getPackageInfo → signatures[0].toCharsString()`);
   - сверяет её с константой, расшифрованной фиксированным 6-байтовым ключом
     (`.rodata:0x66f0` = `04 08 0f 10 17 2a`, период 6) — в константе лежит hex
     сертификата автора (O=syxme, L=Moscow);
   - читает `JarFile` собственного APK: CRC32(`classes.dex`) (`bswap` → 4 байта ключа),
     считает записи манифеста (счётчики правят `key[0]`, `key[1]`);
   - собирает 38-байтовый ключ: `key[2i] = "syxme.lkmp.VKMPLite"[i] ^ table9[i%9]`,
     `key[2i+1] = bswap32(CRC32(classes.dex))[i%4]`, затем XOR-фолд hex подписи в ключ;
   - этим ключом (период 38) расшифрованы все константы протокола.
   Пересборка APK ⇒ другой CRC/подпись ⇒ мусор вместо констант ⇒ ошибка 9.

## Восстановленный протокол (расшифрованные строки)

| Что | Значение |
|---|---|
| Аноним-токен | `POST https://api.vk.ru/oauth/get_anonym_token` |
| Тело аноним-токена | `client_id=2274003&client_secret=hHbZxrka2uZ6jB1inYsH&lang=ru&https=1&api_id=2274003&device_id=…&v=…` |
| Парольный вход | `POST https://api.vk.ru/oauth/token`, `grant_type=password`, `sak_version=1.104`, `v=5.205`, `flow_type=auth_without_password`, `gaid=236fd493-f8a3-4c52-97d4-acae50a72221` (зашит в .so) |
| Вход по sid (после OTP) | `POST https://api.vk.ru/oauth/token`, `grant_type=phone_confirmation_sid`, `sak_version=1.123`, `flow_type=tg_flow`, `device_id=…`, `device_trusted_hash_supported=1`, `supported_ways=push,email` |
| validateAccount | `POST https://api.vk.ru/method/auth.validateAccount`, `supported_ways=push,email,sms,callreset,password,reserve_code,codegen`, `force_password=0`, `sak_version=1.123`, БЕЗ `v` |
| checkOtp / getVerificationMethods | `…/method/ecosystem.checkOtp`, `…/method/ecosystem.getVerificationMethods`, база `lang=ru&https=1&api_id=2274003` |
| registerDevice | `app_version=21014` ⇒ клиент маскируется под VKAndroidApp/8.87-21014 |
| Refresh | `POST https://api.vk.ru/oauth/auth_by_exchange_token`, `lang=en`, `sak_version=1.104`, `initiator=expired_token` |
| API-вызовы после логина | `GET https://api.vk.com/method/<имя>?v=…&access_token=…&…&sig=<md5hex>` |

**Формула sig** (vMethod): `sig = md5hex("/method/" + name + "?v=" + v + "&access_token=" +
token + "&device_id=…" + "&" + params_pullWithoutEncode)` — MD5 от строки запроса с
НЕзакодированными параметрами; в URL при этом уходят закодированные (`pull()`).
Client_secret в sig НЕ входит. Считается через Java `MessageDigest("MD5")` + `textUtils.hex`.

## Почему была ошибка 9 сразу (не спам)

Порт отправлял `auth.getAnonymToken` на `/method/…` с параметрами от «нового» приложения
(`sak_version=1.144.0`, `v=5.276`, UA 8.175-51775, случайный gaid). Нативный клиент шлёт
аноним-токен на отдельный `/oauth/get_anonym_token` со значениями «старого» клиента
(`sak_version=1.123/1.104`, `v=5.205`, UA 8.87-21014, фиксированный gaid). Несоответствие
профиля клиента = мгновенный анти-абьюз ответ «9 Flood control».

## Исправления в vk_lkmp_auth.dart

- `getAnonymToken` → `POST /oauth/get_anonym_token` (было `/method/auth.getAnonymToken`).
- `_v` 5.276 → **5.205**, `_sak` 1.144.0 → **1.123**, добавлен `_sak104=1.104`.
- Парольный вход: `grant_type=password` + `sak_version=1.104` + `flow_type=auth_without_password`
  (было гибридное `phone_confirmation_sid` + `username/password`).
- Пустой пароль (skip-путь): тело `0x4460` — `phone_confirmation_sid` + sid + anonymous_token.
- `supported_ways` укорочен до нативного списка; из validateAccount/checkOtp/sendOtp/getVerificationMethods
  убран `v` (в нативных телах его нет).
- `gaid` — константа из .so (был случайный UUID), UA — `VKAndroidApp/8.87-21014…` (было 8.175-51775).
- Refresh: `lang=en`, `sak_version=1.104`, `v=5.205` по телу 0x4820.
- Заголовок `X-Get-Processing-Time: 1` добавлен (ставится нативным method()).

## Скрипты анализа (сохранены в /home/z/my-project/scripts/)

- `so_strings.py` — разрешение строк из дизассемблера;
- `derive_key.py` / `solve_key.py` — попытки вывода ключа из модели;
- `recover_key_fast.py` — поиск по известному открытому тексту (numpy);
- `decrypt_all.py` / `sweep_decrypt.py` — финальная расшифровка (ключ в
  `work/lkmp_extract/final_key.hex`).

## Дальше (если API-вызовы после логина будут отклоняться)

`_apiCall` в Dart пока POST-ит на `api.vk.ru` без sig. Нативный vMethod делает GET на
`api.vk.com/method/…` с `sig=md5hex(...)` по формуле выше — при необходимости добавить.
