# VK Auth — тестовые ссылки

Открой каждую в браузере (лучше инкогнито). Правильная — попросит логин и после входа кинет на `https://oauth.vk.ru/blank.html#access_token=...` или `?code=...`. Ошибочная — сразу `Unknown method passed [3]` или `not found app`.

> Скажи номер какая сработала — оставлю её в коде.

## 1. oauth.vk.com — implicit token (без PKCE) — для сайта 6287487 как ты просил
**1a. 6287487 site — token — audio+offline**
```
https://oauth.vk.com/authorize?client_id=6287487&scope=audio,offline&redirect_uri=https://oauth.vk.ru/blank.html&display=mobile&response_type=token&v=5.131&revoke=1&state=test1
```
**1b. 6287487 site — token — audio,video,offline,friends,groups,wall**
```
https://oauth.vk.com/authorize?client_id=6287487&scope=audio,video,offline,friends,groups,wall&redirect_uri=https://oauth.vk.ru/blank.html&display=mobile&response_type=token&v=5.131&revoke=1&state=test1b
```
**1c. 6287487 site — code**
```
https://oauth.vk.com/authorize?client_id=6287487&scope=audio,offline&redirect_uri=https://oauth.vk.ru/blank.html&display=mobile&response_type=code&v=5.131&revoke=1&state=test1c
```

## 2. oauth.vk.com — проверенные ID
**2a. 6121396 Kate Mobile — token — классика**
```
https://oauth.vk.com/authorize?client_id=6121396&scope=audio,offline&redirect_uri=https://oauth.vk.ru/blank.html&display=mobile&response_type=token&v=5.131&revoke=1&state=test2a
```
**2b. 2274003 VK Android — token**
```
https://oauth.vk.com/authorize?client_id=2274003&scope=audio,offline,friends,wall,groups,video&redirect_uri=https://oauth.vk.ru/blank.html&display=mobile&response_type=token&v=5.131&revoke=1&state=test2b
```
**2c. 52461373 VK Video — token**
```
https://oauth.vk.com/authorize?client_id=52461373&scope=video,friends,groups,wall&redirect_uri=https://oauth.vk.ru/blank.html&display=mobile&response_type=token&v=5.131&revoke=1&state=test2c
```
**2d. 51858169 — token**
```
https://oauth.vk.com/authorize?client_id=51858169&scope=video,friends,groups,wall,audio,offline&redirect_uri=https://oauth.vk.ru/blank.html&display=mobile&response_type=token&v=5.131&revoke=1&state=test2d
```

## 3. id.vk.com — PKCE code flow (нужен code_challenge)
Демо challenge: `E9Melhoa2OwvFrEMTJguCHaoe2t8e8a8d2c3b4e5f6a7b8c9d0e1f2a3b4c5d6e7` — если не пустит, скажи — сгенерю свежий.

**3a. 51858169 id.vk.com PKCE (рабочий из Kotlin-референса)**
```
https://id.vk.com/authorize?state=test3a&response_type=code&code_challenge=E9Melhoa2OwvFrEMTJguCHaoe2t8e8a8d2c3b4e5f6a7b8c9d0e1f2a3b4c5d6e7&code_challenge_method=S256&client_id=51858169&lang_id=0&scheme=space_gray&scope=video,friends,groups,wall&prompt=login&redirect_uri=https://oauth.vk.ru/blank.html
```
**3b. 6287487 site на id.vk.com PKCE (тот что давал not found app id)**
```
https://id.vk.com/authorize?state=test3b&response_type=code&code_challenge=E9Melhoa2OwvFrEMTJguCHaoe2t8e8a8d2c3b4e5f6a7b8c9d0e1f2a3b4c5d6e7&code_challenge_method=S256&client_id=6287487&lang_id=0&scheme=space_gray&scope=audio,video,offline,friends,groups,wall&prompt=login&redirect_uri=https://oauth.vk.ru/blank.html
```
**3c. 2274003 id.vk.com PKCE**
```
https://id.vk.com/authorize?state=test3c&response_type=code&code_challenge=E9Melhoa2OwvFrEMTJguCHaoe2t8e8a8d2c3b4e5f6a7b8c9d0e1f2a3b4c5d6e7&code_challenge_method=S256&client_id=2274003&lang_id=0&scheme=space_gray&scope=video,friends,groups,wall&prompt=login&redirect_uri=https://oauth.vk.ru/blank.html
```

## 4. Разные redirect_uri (если blank.html режет)
**4a. 6287487 с https://oauth.vk.com/blank.html**
```
https://oauth.vk.com/authorize?client_id=6287487&scope=audio,offline&redirect_uri=https://oauth.vk.com/blank.html&display=mobile&response_type=token&v=5.131&revoke=1&state=test4a
```
**4b. 6121396 с https://oauth.vk.com/blank.html**
```
https://oauth.vk.com/authorize?client_id=6121396&scope=audio,offline&redirect_uri=https://oauth.vk.com/blank.html&display=mobile&response_type=token&v=5.131&revoke=1&state=test4b
```

---
### Что писать в ответ:
`1a — ок, дала токен` / `1b — Unknown method passed [3]` / `3a — not found` и т.д. 
По твоему ответу зафиксирую один ID+метод и соберу APK.
