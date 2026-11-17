String fmtTime(Duration? d) {
  if (d == null || d < Duration.zero) return '--:--';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
}

String fmtSize(int bytes) {
  if (bytes < 1024) return '$bytes Б';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} КБ';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} МБ';
  return '${(mb / 1024).toStringAsFixed(2)} ГБ';
}

String fmtDate(int epochMs) {
  final d = DateTime.fromMillisecondsSinceEpoch(epochMs);
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd.$mm.${d.year}';
}

String fmtFreq(double hz) {
  return hz >= 1000
      ? '${(hz / 1000).toStringAsFixed(0)} кГц'
      : '${hz.toStringAsFixed(0)} Гц';
}

String fmtGain(double g) {
  final v = g.toStringAsFixed(0);
  return g > 0 ? '+$v дБ' : '$v дБ';
}
