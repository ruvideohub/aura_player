/// Глобальный держатель пути, переданного при запуске через ассоциацию / двойной клик
/// На Windows: explorer запускает aura_player.exe "C:\video.mp4"
/// На macOS/Linux: аналогично
String? initialLaunchPath;

void setInitialLaunchPath(String? p) => initialLaunchPath = p;
