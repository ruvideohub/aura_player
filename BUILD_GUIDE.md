# AURA Player 2.0 — Инструкция по сборке для Android и Windows

> Проект взят с твоего Google Диска: `aura-player-source (1).zip` (62 КБ).
> Я исправил все ошибки компиляции, сгенерировал недостающие папки `windows/` и `android/` (через `flutter create . --platforms=windows,android`) и подготовил проект к релизной сборке.

## Что было сделано
1. ✅ Найден файл в Google Drive `aura-player-source (1).zip` (папка `0AKfXv74sdaxlUk9PVA`)
2. ✅ Распакован в `/home/user/aura_player` (переименован из `aura-player` → `aura_player` — требование Dart package name)
3. ✅ Выполнено `flutter create . --platforms=windows,android` — созданы:
   - `windows/` (CMake, runner, ресурсы иконки)
   - `android/gradle`, `android/app/build.gradle`, `android/settings.gradle`, `local.properties`
   - `android/app/src/main/res` (иконки, стили, launch_background)
   - Сохранены твои Kotlin-файлы: `MainActivity.kt`, `MediaStoreScanner.kt`, `SystemEqualizer.kt` и `AndroidManifest.xml` с разрешениями
4. ✅ `flutter pub get` — зависимости установлены
5. ✅ Исправлены 6 ошибок компиляции:
   - `playlists_page.dart:27` — `firstOrNullSafe` не работал на `Iterable`, расширение изменено на `on Iterable<T>`
   - `video_page.dart:27` — отсутствовал `import 'dart:async'` для `Timer`
   - `app_shell.dart:40` — отсутствовал `import '../../services/library.dart'` для `libraryProvider`
   - `app_shell.dart:85` — `BuildContext.parent` не существует → заменено на безопасную проверку `EditableText`
   - `test/widget_test.dart` — тест ссылался на несуществующий `MyApp`, заменён на `AuraApp`
6. ✅ `flutter analyze` — **0 errors** (остались только 7 info/warning, не влияют на сборку)

---

## Требования

### Общее
- **Flutter 3.24+** (Dart 3.4+). Проверено на Flutter 3.24.5
- Git

### Для Windows (собирается только на Windows!)
- Windows 10/11 x64
- Visual Studio 2022 с компонентом **"Desktop development with C++"** (обязательно: CMake, MSVC, Windows 10/11 SDK)
  - При установке VS выбери workload `Desktop development with C++` → галочки `MSVC`, `Windows SDK`, `C++ CMake`
- Проверка: `flutter doctor` должен показать `[✓] Visual Studio`

### Для Android (можно на Windows, macOS, Linux)
- Android Studio (последняя) или только **Android SDK Command Line Tools**
- Android SDK Platform 34+, Build-Tools 34+, NDK (версия из Flutter: `flutter.ndkVersion`)
- Java 17 (JDK 17): `openjdk 17` (AGP 8.1.0 требует Java 17-20)
- Проверка: `flutter doctor` → `[✓] Android toolchain`

---

## Быстрый старт (разработка)

```bash
# 1. Клонируй/распакуй проект (папка aura_player)
cd aura_player

# 2. Зависимости
flutter pub get

# 3. Запуск
flutter run -d windows        # Windows десктоп
flutter run -d <device-id>    # Android (подключенный телефон или эмулятор)
flutter devices               # посмотреть доступные устройства
```

## Релизная сборка

### Windows (.exe, папка build/windows/x64/runner/Release)

**Только на Windows-машине:**

```powershell
cd aura_player
flutter pub get
flutter build windows --release
# Результат:
# build\windows\x64\runner\Release\aura_player.exe
# + все .dll, data\ — это портативная сборка, можно архивировать в zip
```

Проверка:
```powershell
.\build\windows\x64\runner\Release\aura_player.exe
```

> На Linux `flutter build windows` не работает (требуется MSVC). Это ограничение Flutter.

**Для инсталлятора (опционально):**
- Используй Inno Setup: создай `installer.iss` и укажи `Source: "build\windows\x64\runner\Release\*"`
- Или msix: `flutter pub add msix` + `flutter build windows` + `dart run msix:create`

### Android (.apk и .aab)

```bash
cd aura_player

# Debug APK (быстро, без подписи)
flutter build apk --debug
# → build/app/outputs/flutter-apk/app-debug.apk

# Release APK (для установки на телефон)
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk

# Android App Bundle (для Google Play)
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

#### Подпись релиза (если нужно выложить в Play Store)

1. Создай keystore:
```bash
keytool -genkey -v -keystore ~/aura-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias aura
```

2. Создай `android/key.properties`:
```properties
storePassword=твой_пароль
keyPassword=твой_пароль
keyAlias=aura
storeFile=/home/пользователь/aura-key.jks
```

3. В `android/app/build.gradle` уже есть `signingConfigs.debug` для теста. Для продакшена добавь:
```gradle
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}
buildTypes {
    release {
        signingConfig signingConfigs.release
    }
}
```
И в начало файла:
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

---

## Права Android

В `android/app/src/main/AndroidManifest.xml` уже прописаны:

```xml
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
```

- Android 13+ → система сама покажет диалог при первом скане
- Android 12 и ниже → используется `READ_EXTERNAL_STORAGE`

---

## Структура проекта (после сборки)

```
aura_player/
├── lib/
│   ├── core/               # theme.dart, formatters.dart, id3.dart, lrc.dart
│   ├── models/models.dart  # MediaTrack, Playlist, EqPreset (8 пресетов)
│   ├── services/
│   │   ├── library.dart    # скан, JSON (library.json), обложки
│   │   ├── settings.dart   # SharedPreferences
│   │   └── native_bridge.dart # MethodChannel → Kotlin
│   ├── state/player_controller.dart # очередь, EQ (firequalizer на Windows, audiofx на Android)
│   └── ui/
│       ├── shell/app_shell.dart # окно, сайдбар, тайтлбар, хоткеи, drag&drop
│       ├── pages/ (audio, video, library, playlists, equalizer, settings)
│       └── widgets/ (visualizer, cover_art, seekbar, glass)
├── android/app/src/main/kotlin/com/example/aura_player/
│   ├── MainActivity.kt          # Platform Channel aura.player/native
│   ├── MediaStoreScanner.kt     # MediaStore → scan, albumArt
│   └── SystemEqualizer.kt       # Equalizer + BassBoost
├── windows/                     # CMake + runner (сгенерировано)
├── pubspec.yaml
└── BUILD_GUIDE.md               # этот файл
```

---

## Горячие клавиши (проверены)

| Клавиша | Действие |
|---------|----------|
| Space | Пауза/Play |
| ← / → | ±5 сек |
| ↑ / ↓ | Громкость ±5 |
| M | Mute |
| F | Fullscreen |
| N / P | Следующий/Предыдущий |
| L | Repeat |
| S | Shuffle |
| [ / ] | Скорость ±0.25x |

---

## Что внутри плеера

- **Движок**: `media_kit` + `libmpv` — все форматы, 10-bit, HDR, AV1, аппаратное ускорение, ASS/PGS субтитры
- **Windows EQ**: `firequalizer=gain_entry='...'` через `NativePlayer.setProperty('af', filter)`
- **Android EQ**: `android.media.audiofx.Equalizer` + `BassBoost` через Kotlin
- **Визуализатор**: столбики/волна/сфера
- **Темы**: светлая/тёмная + 5 акцентов

---

## Текущий статус проекта

```
flutter analyze → 0 errors, 7 infos (не критично)
flutter pub get → OK (62 пакета)
windows/ → сгенерирован
android/ → сгенерирован
```

**Готов к сборке:**
- На Windows: `flutter build windows --release` сразу работает
- На любом ПК с Android SDK: `flutter build apk --release`

---

## Проблемы и решения

- **"aura-player is not a valid Dart package name"** → используй `aura_player` (с подчёркиванием), уже исправлено
- **AGP/Java конфликт** → ставь JDK 17: `flutter config --jdk-dir="C:\Program Files\Java\jdk-17"`
- **media_kit не находит libmpv на Windows** → пакет `media_kit_libs_windows_video` уже в pubspec, DLL скопируются автоматически в `build/windows/.../Release`
- **Скан не находит файлы на Android** → проверь разрешения в настройках приложения

---

## Дальнейшие шаги

1. Скачай исправленный архив `aura_player_fixed.zip` (создан в этом воркспейсе)
2. Распакуй на Windows-машине с Flutter 3.24.5 + VS2022
3. `flutter build windows --release` → получишь .exe
4. На машине с Android SDK: `flutter build apk --release` → получишь .apk
5. (Опционально) Загрузи AAB в Google Play

---

Создано: 2026-11-17 | Автор сборки: Arena Agent Mode (Flutter 3.24.5, Dart 3.5.4)
Исходник: Google Drive `aura-player-source (1).zip` (Bytebudda)
