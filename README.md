# AURA Player 2.0 — Flutter + Kotlin

Красивый и супер удобный аудио и видео плеер, переписанный с веба в нативный стек:

- **Flutter (Material 3)** — весь интерфейс: один код для Windows и Android
- **Kotlin** — нативный слой Android: MediaStore-сканер, обложки, системный эквалайзер
- **libmpv (media_kit)** — движок воспроизведения: все форматы, аппаратное ускорение, субтитры
- **Riverpod** — состояние плеера: очередь, шаффл, повтор, позиции файлов

## Возможности

| Раздел | Что умеет |
| --- | --- |
| Видео | MKV, MP4, HEVC, AV1, 10-bit, HDR; субтитры SRT/ASS/PGS (встроенные и внешние), выбор аудиодорожек, скорость 0.25–2x, полный экран, жесты и колесо мыши |
| Аудио | Обложки из ID3/MediaStore, визуализатор (столбики / волна / сфера), синхронный текст .lrc, скорость с сохранением питча |
| Эквалайзер | 10 полос (32 Гц–16 кГц), 8 пресетов + своя настройка; Windows — mpv firequalizer, Android — audiofx (Kotlin) |
| Библиотека | Рекурсивный скан папок, ID3-парсер (без внешних пакетов), поиск, сортировка; на Android — MediaStore |
| Плейлисты | Создание, переименование, drag-and-drop, автосохранение |
| Ещё | Запоминание позиции, таймер сна, drag & drop файлов в окно, горячие клавиши, тёмная/светлая темы, 5 акцентов, кастомный тайтлбар |

## Требования

- Flutter **3.24+** (Dart 3.4+)
- Для Windows: Visual Studio 2022 с компонентом "Desktop development with C++"
- Для Android: Android SDK / студия

## Сборка

```bash
# 1. Сгенерировать платформенный каркас (папки windows/ и android-gradle)
cd aura-player
flutter create . --platforms=windows,android

# 2. Зависимости
flutter pub get

# 3. Запуск в разработке
flutter run -d windows            # Windows
flutter run -d <device-id>        # Android

# 4. Релизные сборки
flutter build windows --release   # .exe
flutter build apk --release       # .apk
```

> `flutter create .` создаёт недостающие платформенные файлы и не трогает
> уже существующие (lib/, kotlin-классы, манифест, pubspec.yaml).

### Права Android

Манифест уже содержит `READ_MEDIA_AUDIO`, `READ_MEDIA_VIDEO` (Android 13+)
и `READ_EXTERNAL_STORAGE` (до Android 12). На Android 13+ система сама
покажет запрос при первом скане.

## Структура проекта

```
aura-player/
├── lib/
│   ├── core/               # тема, форматтеры, ID3-парсер, .lrc
│   ├── models/             # MediaTrack, Playlist, пресеты EQ
│   ├── services/
│   │   ├── settings.dart   # SharedPreferences + все настройки
│   │   ├── library.dart    # скан, JSON-хранилище, обложки, плейлисты
│   │   └── native_bridge.dart  # MethodChannel к Kotlin
│   ├── state/
│   │   └── player_controller.dart  # очередь, EQ, позиции, таймер сна
│   └── ui/
│       ├── shell/          # окно, сайдбар, мини-плеер, хоткеи
│       ├── pages/          # музыка, видео, библиотека, плейлисты, EQ, настройки
│       └── widgets/        # визуализатор, обложки, seekbar, стекло
├── android/app/src/main/
│   ├── AndroidManifest.xml
│   └── kotlin/com/example/aura_player/
│       ├── MainActivity.kt          # Platform Channels
│       ├── MediaStoreScanner.kt     # скан устройства + обложки
│       └── SystemEqualizer.kt       # audiofx: EQ + бас-буст
└── pubspec.yaml
```

## Горячие клавиши

| Клавиша | Действие |
| --- | --- |
| Space | Пауза / воспроизведение |
| ← / → | Перемотка −5 с / +5 с |
| ↑ / ↓ | Громкость ±5 |
| M | Без звука |
| F | Полный экран |
| N / P | Следующий / предыдущий трек |
| L | Режим повтора: выкл → все → один |
| S | Перемешивание |
| [ / ] | Скорость −0.25x / +0.25x |

## Как работает эквалайзер

- **Windows:** контроллер собирает фильтр `firequalizer=gain_entry='…'` и
  назначает его mpv-свойству `af` через `NativePlayer.setProperty`.
  Применяется мгновенно и к текущему, и к будущим трекам.
- **Android:** `SystemEqualizer` подключает `android.media.audiofx.Equalizer`
  к выходному миксу, уровни передаются в миллибеллах по MethodChannel.
- Пресеты — те же, что в веб-версии AURA (Плоский, Бас+, Рок, Поп, Джаз,
  Классика, Вокал, Электроника).

## Дорожная карта

- SMTC-интеграция Windows (системные медиа-кнопки) через `smtc_windows`
- Foreground-сервис Android для воспроизведения в фоне
- Экспорт/импорт плейлистов в M3U
