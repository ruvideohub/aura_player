import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Индекс активной страницы:
/// 0 — музыка, 1 — видео, 2 — библиотека, 3 — плейлисты,
/// 4 — эквалайзер, 5 — настройки.
final pageProvider = StateProvider<int>((ref) => 0);

/// Полноэкранный режим видео (скрывает боковую панель и мини-плеер).
final fullscreenProvider = StateProvider<bool>((ref) => false);
