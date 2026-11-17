import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Индекс активной страницы:
/// 0 — музыка, 1 — видео, 2 — библиотека, 3 — плейлисты,
/// 4 — эквалайзер, 5 — настройки.
final pageProvider = StateProvider<int>((ref) => 0);

/// Полноэкранный режим видео (скрывает боковую панель и мини-плеер).
final fullscreenProvider = StateProvider<bool>((ref) => false);

// ── Видео: режим масштабирования (aspect ratio / fit) ──────────────

/// Режим отображения видео — как в Poweramp / MX Player
enum VideoFit {
  /// Вместить целиком, чёрные поля — по умолчанию
  contain,
  /// Заполнить экран с обрезкой (cover)
  cover,
  /// Растянуть на весь экран с искажением
  stretch,
  /// Принудительно 16:9
  sixteenNine,
  /// Принудительно 4:3
  fourThree,
}

extension VideoFitLabel on VideoFit {
  String get label {
    switch (this) {
      case VideoFit.contain: return 'Вписать';
      case VideoFit.cover: return 'Заполнить';
      case VideoFit.stretch: return 'Растянуть';
      case VideoFit.sixteenNine: return '16:9';
      case VideoFit.fourThree: return '4:3';
    }
  }

  String get shortLabel {
    switch (this) {
      case VideoFit.contain: return 'FIT';
      case VideoFit.cover: return 'FILL';
      case VideoFit.stretch: return 'STRETCH';
      case VideoFit.sixteenNine: return '16:9';
      case VideoFit.fourThree: return '4:3';
    }
  }
}

final videoFitProvider = StateProvider<VideoFit>((ref) => VideoFit.contain);
