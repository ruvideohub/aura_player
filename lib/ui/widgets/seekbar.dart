import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../state/player_controller.dart';

/// Ползунок прогресса с метками времени.
/// Поддерживает drag-preview: во время перетаскивания показываем _dragValue,
/// а `onSeek` вызываем только на `onChangeEnd` — не спамим ExoPlayer seek'ами.
class SeekBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final VoidCallback? onSeekStart;
  final VoidCallback? onSeekEnd;
  final bool showTimes;
  final bool compact;
  // dragValue — если не null, показываем его вместо position (preview)
  final double? dragValue;

  const SeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.onSeekStart,
    this.onSeekEnd,
    this.showTimes = true,
    this.compact = false,
    this.dragValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxMs = duration.inMilliseconds.toDouble();
    final usableMax = maxMs > 0 ? maxMs : 1.0;
    final value = (dragValue ?? position.inMilliseconds.clamp(0, maxMs > 0 ? maxMs.toInt() : 1).toDouble())
        .clamp(0.0, usableMax);

    // Во время drag показываем drag-время, иначе — реальную позицию
    final displayPos = dragValue != null ? Duration(milliseconds: dragValue!.round()) : position;

    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: compact ? 3 : 4,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: compact ? 6 : 7),
        overlayShape: RoundSliderOverlayShape(overlayRadius: compact ? 12 : 14),
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      child: Slider(
        value: value,
        max: usableMax,
        onChangeStart: onSeekStart != null ? (_) => onSeekStart!.call() : null,
        onChangeEnd: onSeekEnd != null ? (_) => onSeekEnd!.call() : null,
        onChanged: maxMs > 0 ? (v) => onSeek(Duration(milliseconds: v.round())) : null,
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
        if (showTimes) SizedBox(width: 48, child: Text(fmtTime(displayPos), style: style)),
        Expanded(child: slider),
        if (showTimes)
          SizedBox(width: 48, child: Text(fmtTime(duration), style: style, textAlign: TextAlign.end)),
      ],
    );
  }
}

/// Живой сикбар — позиция через Stream, но seek только на отпускание.
/// Во время drag не дергаем плеер, только preview. Флагман + 4K/HLS плавнее в разы.
class LiveSeekBar extends ConsumerStatefulWidget {
  final bool compact;
  final bool showTimes;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  const LiveSeekBar({super.key, this.compact = false, this.showTimes = true, this.onDragStart, this.onDragEnd});

  @override
  ConsumerState<LiveSeekBar> createState() => _LiveSeekBarState();
}

class _LiveSeekBarState extends ConsumerState<LiveSeekBar> {
  double? _dragValue; // null = не тянем, иначе preview позиция в ms

  @override
  Widget build(BuildContext context) {
    final duration = ref.watch(playerProvider.select((p) => p.duration));
    final player = ref.read(playerProvider);

    return StreamBuilder<Duration>(
      stream: player.positionStream,
      initialData: player.position,
      builder: (_, snap) {
        final pos = snap.data ?? player.position;
        return SeekBar(
          position: pos,
          duration: duration,
          compact: widget.compact,
          showTimes: widget.showTimes,
          dragValue: _dragValue,
          onSeekStart: () {
            widget.onDragStart?.call();
          },
          onSeekEnd: () {
            final v = _dragValue;
            if (v != null) {
              // единственный seek за весь жест — как в Kotlin onSeekEnd
              player.seek(Duration(milliseconds: v.round()));
            }
            setState(() => _dragValue = null);
            widget.onDragEnd?.call();
          },
          onSeek: (d) {
            // preview без вызова плеера — только UI
            setState(() => _dragValue = d.inMilliseconds.toDouble());
          },
        );
      },
    );
  }
}
