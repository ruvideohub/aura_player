# AURA Player — TODO vs Poweramp + Next Player

> Цель: догнать Poweramp (аудио) + Next Player (видео). Версия старта: 2.0.0+5

## Как работать с Todo
- [ ] — не начато, [x] — готово, [~] — в процессе
- Приоритет: P0 — критично, P1 — важно, P2 — полировка
- Каждый пункт — отдельная ветка/коммит

---

## Этап 0 — Быстрые wins (1–2 дня)
- [x] **0.1** Bass Boost UI + limiter toggle в EqualizerPage — P0 — **готово f50fe5e**
- [x] **0.2** Sleep fade-out 15s (volume ramp) — P0 — **готово f50fe5e**
- [x] **0.3** PIP флаг в AndroidManifest — P1 — **готово 2.0.0+7**
- [ ] **0.4** Визуализатор barCount 64 + 60fps + FFT заготовка — P1
- [x] **0.5** Сохранение очереди между рестартами — P1 — **готово f50fe5e (queue.json)**

## Этап 1 — Библиотека и навигация (паритет) — P0/P1
- [x] **1.1** Сканирование в изоляте + прогресс % + инкрементальный DATE_MODIFIED — P0 — **готово 2.0.0+7 (compute + prune)**
- [x] **1.2** Прун удалённых файлов на Android — P0 — **готово 2.0.0+7 (scannedPaths diff)**
- [ ] **1.3** SAF-пикер папок на Android (Storage Access Framework) — P0
- [ ] **1.4** Группировки: Альбомы / Исполнители / Жанры / Папки / Недавно добавленные / Недавние — P1
- [ ] **1.5** Мультиселект (long-press → чекбоксы) + действия — P1
- [ ] **1.6** Свайпы в списках: вправо — в очередь, влево — удалить — P1
- [ ] **1.7** Глобальный SearchBar в AppShell + сохранение ScrollController — P1
- [ ] **1.8** Дисковый кэш обложек (LRU 100) — P1
- [ ] **1.9** Расширенный парсер тегов: Vorbis/MP4/WMA/APE — P1

## Этап 2 — Видео vs Next Player — P0/P1
- [ ] **2.1** Вернуть аудио-дорожки/субтитры на Android (ExoPlayer TrackSelector + SubtitleView) — P0
- [x] **2.2** Жесты: левая треть — яркость, правая — громкость, пинч — зум, двойной тап ±10с — P0 — **готово 2.0.0+7 (brightness/volume overlay)**
- [x] **2.3** PIP + hardware/software decode toggle + HDR инфо — P1 — **PIP флаг готово 2.0.0+7**
- [ ] **2.4** Скриншот / A-B повтор / remember zoom/brightness per video — P2

## Этап 3 — Аудио PRO vs Poweramp — P1/P2
- [ ] **3.1** Bass/Virtualizer/Reverb/Loudness UI + пер-устройство пресеты — P1
- [ ] **3.2** FFT-визуализатор (Android Visualizer API → CustomPainter) — P1
- [ ] **3.3** Gapless toggle + Crossfade 1–12s (двойной плеер микшер) — P2
- [ ] **3.4** ReplayGain сканер + нормализация — P2
- [ ] **3.5** Статистика playCount/lastPlayed/skipCount + топ-рейтинг — P1

## Этап 4 — Плейлисты и данные — P1
- [ ] **4.1** Smart-плейлисты: недавние, топ, часто играемые — P1
- [ ] **4.2** M3U/M3U8/PLS импорт/экспорт + share — P1
- [ ] **4.3** Бэкап/восстановление (zip: library+playlists+positions+settings) — P1
- [ ] **4.4** Редактор тегов — P2

## Этап 5 — Полировка — P2
- [ ] **5.1** AMOLED тема + плотность списка + анимации shared-element — P2
- [ ] **5.2** Widgets / Android Auto (media_browser_service) — P2
- [ ] **5.3** Debounce persist (500ms) + atomic write + Crashlytics — P2

---

## Текущий фокус
**Начинаем с: 0.1 Bass Boost + 0.2 Sleep fade + 1.1 Изолят скан** — параллельно, первый коммит сегодня.

Прогресс: 8/24 готово — следующий: 1.4 группировки + 1.5 мультиселект
