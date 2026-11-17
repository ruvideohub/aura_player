import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/settings.dart';

/// Декоративный визуализатор с тремя режимами: столбики, волна, сфера.
/// Живёт в такт воспроизведению, как в веб-версии AURA.
class Visualizer extends StatefulWidget {
  final bool playing;
  final VisualizerMode mode;
  final double opacity;
  final Color color;
  final int barCount;

  const Visualizer({
    super.key,
    required this.playing,
    required this.mode,
    required this.color,
    this.opacity = 0.85,
    this.barCount = 42,
  });

  @override
  State<Visualizer> createState() => _VisualizerState();
}

class _VisualizerState extends State<Visualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  final math.Random _rng = math.Random(7);
  late final List<double> _phases = List.generate(
    widget.barCount,
    (_) => _rng.nextDouble() * math.pi * 2,
  );
  late final List<double> _speeds = List.generate(
    widget.barCount,
    (_) => 0.6 + _rng.nextDouble() * 1.4,
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant Visualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.playing && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.playing && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return CustomPaint(
          painter: _VizPainter(
            t: _c.value,
            playing: widget.playing,
            mode: widget.mode,
            color: widget.color,
            opacity: widget.opacity,
            phases: _phases,
            speeds: _speeds,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _VizPainter extends CustomPainter {
  final double t;
  final bool playing;
  final VisualizerMode mode;
  final Color color;
  final double opacity;
  final List<double> phases;
  final List<double> speeds;

  _VizPainter({
    required this.t,
    required this.playing,
    required this.mode,
    required this.color,
    required this.opacity,
    required this.phases,
    required this.speeds,
  });

  double _level(int i, double wobble) {
    final base = 0.5 + 0.5 * math.sin(t * 2 * math.pi * speeds[i] + phases[i]);
    final second = 0.5 + 0.5 * math.sin(t * 4 * math.pi * speeds[i] + phases[i] * 1.7);
    final v = (base * 0.7 + second * 0.3) * (playing ? 1 : 0.06) + wobble * 0.08;
    return v.clamp(0.04, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withOpacity(opacity);
    final w = size.width;
    final h = size.height;

    if (mode == VisualizerMode.bars) {
      final n = phases.length;
      final slot = w / n;
      final barW = slot * 0.55;
      for (var i = 0; i < n; i++) {
        final env = math.pow(math.sin(math.pi * i / (n - 1)), 0.7).toDouble();
        final v = _level(i, 0) * env;
        final bh = h * (0.08 + 0.92 * v);
        final x = i * slot + (slot - barW) / 2;
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, h - bh, barW, bh),
          Radius.circular(barW / 2),
        );
        canvas.drawRRect(rrect, paint);
      }
    } else if (mode == VisualizerMode.wave) {
      final paint2 = Paint()
        ..color = color.withOpacity(opacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      final path = Path();
      final k = 2 * math.pi / w * 3;
      for (var x = 0.0; x <= w; x += 4) {
        final env = math.pow(math.sin(math.pi * x / w), 1.2).toDouble();
        final y = h / 2 +
            math.sin(x * k + t * 2 * math.pi) *
                (h * 0.32) *
                env *
                (playing ? 1 : 0.1);
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint2);
      // вторая волна со сдвигом фазы
      final path2 = Path();
      for (var x = 0.0; x <= w; x += 4) {
        final env = math.pow(math.sin(math.pi * x / w), 1.2).toDouble();
        final y = h / 2 +
            math.sin(x * k + t * 2 * math.pi + math.pi * 0.66) *
                (h * 0.22) *
                env *
                (playing ? 1 : 0.08);
        if (x == 0) {
          path2.moveTo(x, y);
        } else {
          path2.lineTo(x, y);
        }
      }
      canvas.drawPath(path2, paint2);
    } else {
      // orb — пульсирующая сфера с орбитой точек
      final center = Offset(w / 2, h / 2);
      final r0 = math.min(w, h) * 0.18;
      final pulse = playing
          ? 1 + 0.12 * math.sin(t * 2 * math.pi * 1.3)
          : 1.0;
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(center, r0 * pulse, paint);
      final dotPaint = Paint()
        ..color = color.withOpacity(opacity * 0.75);
      const dots = 36;
      for (var i = 0; i < dots; i++) {
        final angle = 2 * math.pi * i / dots + t * math.pi * (playing ? 1 : 0);
        final r = r0 * (1.55 + 0.35 * _level(i, 0));
        final p = center + Offset(math.cos(angle) * r, math.sin(angle) * r * 0.8);
        canvas.drawCircle(p, 2.4, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VizPainter oldDelegate) => true;
}
