# Как запушить AURA Player в приватный GitHub репо

## Вариант 1: Ты создал пустой репо (рекомендуется)

1. Иди на https://github.com/new
   - Repository name: `aura_player`
   - Description: `AURA Player 2.0 — Flutter + Kotlin`
   - Visibility: **Private**
   - **НЕ ставь галочки** Add README, .gitignore, license — репо должен быть пустым!
   - Нажми Create repository

2. Скопируй URL репо, например:
   ```
   https://github.com/ТВОЙ_ЮЗЕР/aura_player.git
   ```

3. У тебя уже готовый локальный git в `/home/user/aura_player` (73 файла, ветка main).
   Если хочешь запушить прямо из этого воркспейса — дай мне URL и PAT токен (см. Вариант 2).

   Если хочешь запушить с своего компа — скачай архив `aura_player_fixed_v2.zip` или `aura_player_fixed_READY_TO_BUILD.zip` с Google Диска и выполни:

   **Windows (PowerShell):**
   ```powershell
   Expand-Archive aura_player_fixed_v2.zip
   cd aura_player
   git init -b main
   git add .
   git commit -m "feat: AURA Player 2.0 ready to build"
   git remote add origin https://github.com/ТВОЙ_ЮЗЕР/aura_player.git
   git push -u origin main
   ```

   **macOS/Linux:**
   ```bash
   unzip aura_player_fixed_v2.zip
   cd aura_player
   git init -b main
   git add .
   git commit -m "feat: AURA Player 2.0 ready to build"
   git remote add origin https://github.com/ТВОЙ_ЮЗЕР/aura_player.git
   git push -u origin main
   ```

4. После пуша зайди в GitHub → Actions — увидишь workflow `Build AURA Player (Android + Windows)` — он автоматически запустится.
   - Android собирается на `ubuntu-latest` → артефакт `app-release-apk`
   - Windows собирается на `windows-latest` → артефакт `windows-release`
   - Скачать можно в Actions → завершившийся run → Artifacts

## Вариант 2: Дать PAT и я запушу сам из воркспейса

1. Создай Personal Access Token:
   https://github.com/settings/tokens/new
   - Note: `aura_push`
   - Expiration: 7 days
   - Scopes: `repo` (все галочки в секции repo)
   - Generate token → скопируй (начинается с ghp_...)

2. Скинь мне в чат:
   - URL репо: `https://github.com/USER/aura_player.git`
   - Токен: `ghp_...`
   - (Можно временным сообщением, я не сохраняю)

3. Я выполню:
   ```bash
   git remote add origin https://ghp_TOKEN@github.com/USER/aura_player.git
   git push -u origin main
   ```
   И сразу покажу ссылку на Actions.

## Что уже внутри репо
- 73 файла, `flutter analyze` = 0 errors
- `windows/` и `android/` сгенерированы, Kotlin код сохранён
- `.github/workflows/build.yml` — уже настроен

## Если Actions не запускается
- Settings → Actions → General → Workflow permissions → Read and write
- Actions должен быть Enabled для private репо (бесплатно 2000 мин/мес)

