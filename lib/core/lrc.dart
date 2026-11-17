class LrcLine {
  final Duration time;
  final String text;

  const LrcLine(this.time, this.text);
}

/// Синхронизированный текст песни (.lrc).
/// Поддерживает несколько меток времени в одной строке и дроби секунд.
class LrcLyrics {
  final List<LrcLine> lines;

  const LrcLyrics(this.lines);

  static LrcLyrics? parse(String source) {
    final stamp = RegExp(r'\[(\d{1,2}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
    final out = <LrcLine>[];

    for (final raw in source.split(RegExp(r'\r?\n'))) {
      final matches = stamp.allMatches(raw).toList();
      if (matches.isEmpty) continue;
      final text = raw.replaceAll(stamp, '').trim();
      if (text.isEmpty) continue;

      for (final m in matches) {
        final min = int.tryParse(m.group(1) ?? '') ?? 0;
        final sec = int.tryParse(m.group(2) ?? '') ?? 0;
        final frac = m.group(3);
        var ms = 0;
        if (frac != null) {
          if (frac.length == 1) {
            ms = int.parse(frac) * 100;
          } else if (frac.length == 2) {
            ms = int.parse(frac) * 10;
          } else {
            ms = int.parse(frac.padRight(3, '0').substring(0, 3));
          }
        }
        out.add(LrcLine(
          Duration(minutes: min, seconds: sec, milliseconds: ms),
          text,
        ));
      }
    }

    if (out.isEmpty) return null;
    out.sort((a, b) => a.time.compareTo(b.time));
    return LrcLyrics(List.unmodifiable(out));
  }

  /// Индекс активной строки для текущей позиции (бинарный поиск).
  int indexAt(Duration d) {
    var lo = 0;
    var hi = lines.length - 1;
    var ans = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (lines[mid].time <= d) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }
}
