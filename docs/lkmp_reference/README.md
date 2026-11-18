# LKMP_34_2.0.2 — полный референс ВК Музыки (деобфусцированный)

Дата раскопки: 2026-11-18
Исходник: `LKMP_34_2.0.2.apk` (2.0М, R8 обфускация) с Google Drive `0AKfXv74sdaxlUk9PVA`
Инструмент: `jadx 1.4.7` → `/tmp/lkmp_src`

## Зачем
LKMP полностью реализует работу ВК музыки — оставлен для примера на будущее.
Никаких догадок, только то что внутри APK.

## Ключевые файлы (1:1 как в APK)
- `auth_flow_N1_e.java` — `N1/e.java`: весь флоу `auth.getAnonymToken` → `ecosystem.checkOtp` → `ecosystem.getVerificationMethods` → `oauth/auth_by_exchange_token` + fallback `execute.getUserInfo`. Хедеры `X-Screen/Cache-Control/Accept image/webp/X-VK-Android-Client new`, GAID UUID, device_id android_id:hash
- `auth_validate_m1_f.java` — `m1/f.java`: `auth.validateAccount` с `phone`, `supported_ways=push,email,sms,callreset,password,reserve_code,codegen...`, `flow_type=auth_without_password`, капча `captcha_sid/captcha_key`
- `device_id_A_b.java` — `A/b.java`: `x(context)=VKAndroidApp/8.175-51775 (Android 12; SDK31; ...)` и `y(context)=android_id + ":" + hash(Build.*)`
- `lkmp_decompiled_sources/` — полный дамп 1978 файлов `syxme/lkmp/*` + обфусцированные `N1,M1,A,V0` и т.д.
- `sources/` — дубликат для быстрого `grep`
- `LKMP_34_2.0.2.apk` — оригинал (не трогать)

## Константы LKMP (вытащены из N1/e, M1/f, A/b)
```
client_id=2274003
client_secret=hHbZxrka2uZ6jB1inYsH
api_id=2274003
v=5.276
sak_version=1.144.0
flow_type=tg_flow / auth_without_password
host=api.vk.ru/method/auth.getAnonymToken, auth.validateAccount, ecosystem.*, oauth/auth_by_exchange_token, oauth/token
UA=VKAndroidApp/8.175-51775 (Android 12; SDK31; arm64-v8a;Google Nexus 5X; ru; 1920x1080)
headers: X-VK-Android-Client:new, Cache-Control:no-cache, Accept:image/webp, Accept-Encoding:gzip, X-Screen:auth
```

## Порт в AURA
- `lib/services/vk/vk_api.dart` — уже переведён на эти константы
- `lib/services/vk/vk_lkmp_auth.dart` — порт N1/e + M1/f 1:1
- `lib/ui/pages/vk_lkmp_auth_page.dart` — UI копия `slide_auth_code.xml` (#131313, 38dp, 55dp кнопки) + логика выбора метода (sms/push/email/password/reserve_code/codegen)

## Как обновлять
1. Залей новый LKMP.apk на Диск → скачай `google_drive/*.apk`
2. `jadx -d /tmp/new_src new.apk` → скопируй в `docs/lkmp_reference/new_version/`
3. Сравни `diff -r lkmp_decompiled_sources new_version`

## Примечания
- Не удалять `docs/lkmp_reference/` — это эталон.
- Все новые фичи ВК музыки сначала смотреть тут, потом портировать в `vk_lkmp_auth.dart`.
