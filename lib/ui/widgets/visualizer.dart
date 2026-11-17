import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/settings.dart';
import '../../services/visualizer_service.dart';

/// Реальный визуализатор с 3 режимами: bars / wave / orb
/// На Android — берёт данные из Visualizer API (FFT/waveform) прямо из аудио-потока.
/// На Desktop — фоллбек на прокачанный фейк с энтропией от позиции, уже не цикличный.
/// Переключение: playing -> старт/стоп потока, пауза — затухание.
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

class _VisualizerState extends State<Visualizer> with SingleTickerProviderStateMixin {
  late final AnimationController _fakeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  final math.Random _rng = math.Random();
  late final List<double> _phases = List.generate(widget.barCount, (_) => _rng.nextDouble() * math.pi * 2);
  late final List<double> _speeds = List.generate(widget.barCount, (_) => 0.6 + _rng.nextDouble() * 1.4);

  StreamSubscription? _realSub;
  List<double> _levels = [];
  List<double> _wave = [];
  bool _hasReal = false;
  bool _permissionChecked = false;

  @override
  void initState() {
    super.initState();
    _levels = List.filled(widget.barCount, 0.06);
    _wave = List.filled(128, 0.0);
    _sync();
  }

  @override
  void didUpdateWidget(covariant Visualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing || oldWidget.barCount != widget.barCount) {
      if (widget.barCount != oldWidget.barCount) {
        _levels = List.filled(widget.barCount, 0.06);
      }
      _sync();
    }
  }

  void _sync() {
    if (widget.playing) {
      _tryStartReal();
      if (!_hasReal && !_fakeCtrl.isAnimating) {
        // на ПК снижаем частоту до 30fps чтобы не жарить CPU
        if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          _fakeCtrl.repeat(period: const Duration(milliseconds: 33));
        } else {
          _fakeCtrl.repeat();
        }
      }
    } else {
      _stopReal();
      if (_fakeCtrl.isAnimating) _fakeCtrl.stop();
      setState(() => _levels = _levels.map((e) => (e * 0.3).clamp(0.04, 1.0)).toList());
    }
  }

  Future<void> _tryStartReal() async {
    if (!Platform.isAndroid) return;
    if (!_permissionChecked) {
      _permissionChecked = true;
      final has = await VisualizerService.hasPermission();
      if (!has) {
        // запросим тихо, без диалога каждый раз
        await VisualizerService.requestPermission();
      }
    }
    // попробуем подписаться — если VisualizerHelper недоступен, упадёт в error и останемся на фейке
    _realSub?.cancel();
    try {
      final stream = VisualizerService.realStream(sessionId: 0, rate: 20000);
      _realSub = stream.listen((data) {
        final fft = data['fft'] ?? const [];
        final wave = data['waveform'] ?? const [];
        if (fft.isEmpty && wave.isEmpty) return;
        final levels = VizData.fftToLevels(fft, widget.barCount);
        final waveNorm = VizData.waveformToWave(wave);
        if (!mounted) return;
        setState(() {
          _hasReal = true;
          _levels = levels;
          _wave = waveNorm;
        });
        // остановим фейк анимацию если есть реал
        if (_fakeCtrl.isAnimating) _fakeCtrl.stop();
      }, onError: (_) {
        _hasReal = false;
        if (widget.playing && !_fakeCtrl.isAnimating) _fakeCtrl.repeat();
      }, cancelOnError: false);
      // помечаем что пробуем реал — если через 600мс нет данных, остаёмся на фейке
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!_hasReal && mounted && widget.playing && !_fakeCtrl.isAnimating) _fakeCtrl.repeat();
      });
    } catch (_) {
      _hasReal = false;
      if (widget.playing && !_fakeCtrl.isAnimating) _fakeCtrl.repeat();
    }
  }

  void _stopReal() {
    _realSub?.cancel();
    _realSub = null;
    _hasReal = false;
  }

  @override
  void dispose() {
    _fakeCtrl.dispose();
    _realSub?.cancel();
    super.dispose();
  }

  double _fakeLevel(int i) {
    final t = _fakeCtrl.value;
    final base = 0.5 + 0.5 * math.sin(t * 2 * math.pi * _speeds[i] + _phases[i]);
    final second = 0.5 + 0.5 * math.sin(t * 4 * math.pi * _speeds[i] + _phases[i] * 1.7);
    final v = (base * 0.7 + second * 0.3) * (widget.playing ? 1 : 0.06);
    return v.clamp(0.04, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    // если есть реал — рисуем из _levels/_wave, иначе анимируем фейк
    if (_hasReal) {
      return CustomPaint(
        painter: _RealVizPainter(
          levels: _levels,
          wave: _wave,
          playing: widget.playing,
          mode: widget.mode,
          color: widget.color,
          opacity: widget.opacity,
        ),
        size: Size.infinite,
      );
    }
    return AnimatedBuilder(
      animation: _fakeCtrl,
      builder: (context, _) {
        // генерируем уровни на лету для фейка
        final levels = List.generate(widget.barCount, (i) => _fakeLevel(i));
        return CustomPaint(
          painter: _RealVizPainter(
            levels: levels,
            wave: null,
            playing: widget.playing,
            mode: widget.mode,
            color: widget.color,
            opacity: widget.opacity,
            t: _fakeCtrl.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _RealVizPainter extends CustomPainter {
  final List<double> levels;
  final List<double>? wave; // waveform -1..1 for wave mode
  final bool playing;
  final VisualizerMode mode;
  final Color color;
  final double opacity;
  final double t; // for fallback fake wave animation

  _RealVizPainter({
    required this.levels,
    this.wave,
    required this.playing,
    required this.mode,
    required this.color,
    required this.opacity,
    this.t = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withOpacity(opacity);
    final w = size.width;
    final h = size.height;

    if (mode == VisualizerMode.bars) {
      final n = levels.length;
      if (n == 0) return;
      final slot = w / n;
      final barW = slot * 0.55;
      for (var i = 0; i < n; i++) {
        final env = math.pow(math.sin(math.pi * i / (n - 1)), 0.7).toDouble();
        final v = levels[i].clamp(0.0, 1.0) * env;
        // чуть усиливаем динамику: низкие частоты (центр) чуть ниже, края — выше? уже env
        final bh = h * (0.06 + 0.92 * v);
        final x = i * slot + (slot - barW) / 2;
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, h - bh, barW, bh),
          Radius.circular(barW / 2),
        );
        final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
        if (isDesktop) {
          paint.color = color.withOpacity(opacity * (0.7 + 0.3 * v));
          paint.shader = null;
          canvas.drawRRect(rrect, paint);
        } else {
          final grad = LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [color, color.withOpacity(0.6)]).createShader(Rect.fromLTWH(x, h - bh, barW, bh));
          paint.shader = grad;
          canvas.drawRRect(rrect, paint);
          paint.shader = null;
        }
      }
    } else if (mode == VisualizerMode.wave) {
      if (wave != null && wave!.isNotEmpty) {
        // реальная волна
        final path = Path();
        final step = wave!.length / w;
        for (var x = 0.0; x < w; x += 1.5) {
          final idx = (x * step).floor().clamp(0, wave!.length - 1);
          final env = math.pow(math.sin(math.pi * x / w), 1.0).toDouble();
          final y = h / 2 + wave![idx] * (h * 0.38) * env * (playing ? 1 : 0.1);
          if (x == 0) path.moveTo(x, y); else path.lineTo(x, y);
        }
        final p2 = Paint()
          ..color = color.withOpacity(opacity * 0.95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(path, p2);

        if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
          final shadow = Paint()
            ..color = color.withOpacity(opacity * 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
          canvas.drawPath(path, shadow);
        }
      } else {
        // фоллбек волна — старый фейк
        final paint2 = Paint()
          ..color = color.withOpacity(opacity * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        final path = Path();
        final k = 2 * math.pi / w * 3;
        for (var x = 0.0; x <= w; x += 4) {
          final env = math.pow(math.sin(math.pi * x / w), 1.2).toDouble();
          final y = h / 2 + math.sin(x * k + t * 2 * math.pi) * (h * 0.32) * env * (playing ? 1 : 0.1);
          if (x == 0) path.moveTo(x, y); else path.lineTo(x, y);
        }
        canvas.drawPath(path, paint2);
      }
    } else {
      // orb — пульс от басов + точки по кругу от уровней
      final center = Offset(w / 2, h / 2);
      final r0 = math.min(w, h) * 0.18;
      // энергия басов = первые 6 баров
      final bass = levels.isEmpty ? 0.3 : levels.take(6).fold(0.0, (a, b) => a + b) / 6;
      final pulse = playing ? 1 + 0.18 * bass : 1.0;
      paint.style = PaintingStyle.fill;
      final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
      if (!isDesktop) {
        final glow = Paint()
          ..color = color.withOpacity(opacity * 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawCircle(center, r0 * pulse * 1.35, glow);
      }
      canvas.drawCircle(center, r0 * pulse, paint);
      final dotPaint = Paint()..color = color.withOpacity(opacity * 0.85);
      final dots = isDesktop ? 20 : 36;
      for (var i = 0; i < dots; i++) {
        final lvl = i < levels.length ? levels[i % levels.length] : 0.3;
        final angle = 2 * math.pi * i / dots + (playing ? DateTime.now().millisecondsSinceEpoch / 1200 : 0);
        final r = r0 * (1.55 + 0.55 * lvl);
        final p = center + Offset(math.cos(angle) * r, math.sin(angle) * r * 0.8);
        final rad = isDesktop ? 1.5 + lvl * 2.5 : 1.8 + lvl * 3.5;
        canvas.drawCircle(p, rad, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RealVizPainter oldDelegate) => oldDelegate.levels != levels || oldDelegate.wave != wave || oldDelegate.playing != playing || oldDelegate.t != t;
}
