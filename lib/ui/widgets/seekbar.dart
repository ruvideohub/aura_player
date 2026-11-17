import 'package:flutter/material.dart';

import '../../core/formatters.dart';

/// Ползунок прогресса с метками времени.
class SeekBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final bool showTimes;
  final bool compact;

  const SeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.showTimes = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxMs = duration.inMilliseconds.toDouble();
    final value = position.inMilliseconds
        .clamp(0, maxMs > 0 ? maxMs.toInt() : 1)
        .toDouble();
    final usableMax = maxMs > 0 ? maxMs : 1.0;

    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: compact ? 3 : 4,
        thumbShape:
            RoundSliderThumbShape(enabledThumbRadius: compact ? 6 : 7),
        overlayShape:
            RoundSliderOverlayShape(overlayRadius: compact ? 12 : 14),
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      child: Slider(
        value: value,
        max: usableMax,
        onChanged: maxMs > 0
            ? (v) => onSeek(Duration(milliseconds: v.round()))
            : null,
        activeColor: theme.colorScheme.primary,
        inactiveColor: theme.dividerColor,
      ),
    );

    final style = TextStyle(
      fontSize: compact ? 11 : 12,
      color: theme.colorScheme.onSurface.withOpacity(0.6),
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Row(
      children: [
        if (showTimes) SizedBox(width: 44, child: Text(fmtTime(position), style: style)),
        Expanded(child: slider),
        if (showTimes)
          SizedBox(width: 44, child: Text(fmtTime(duration), style: style, textAlign: TextAlign.end)),
      ],
    );
  }
}
