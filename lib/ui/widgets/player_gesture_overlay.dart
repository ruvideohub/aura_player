import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/native_bridge.dart';
import '../../state/player_controller.dart';

String _fmtMs(int ms) {
  final s = (ms / 1000).round();
  final sec = s % 60;
  final min = (s ~/ 60) % 60;
  final hr = s ~/ 3600;
  if (hr > 0) return '${hr.toString()}:${min.toString().padLeft(2,'0')}:${sec.toString().padLeft(2,'0')}';
  return '${min.toString().padLeft(2,'0')}:${sec.toString().padLeft(2,'0')}';
}

/// Оригинал 3410cb0 был простым, но каждый пиксель делал setState + await на мост.
/// Новый: ValueNotifier + троттлинг 32-50мс + fire-and-forget, без перестройки видео.
class PlayerGestureOverlay extends StatefulWidget {
  final Widget child;
  final PlayerController player;
  final VoidCallback onTap;
  final VoidCallback onDoubleTapLeft;
  final VoidCallback onDoubleTapRight;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionUpdate;
  final VoidCallback? onInteractionEnd;
  const PlayerGestureOverlay({
    super.key,
    required this.child,
    required this.player,
    required this.onTap,
    required this.onDoubleTapLeft,
    required this.onDoubleTapRight,
    this.onInteractionStart,
    this.onInteractionUpdate,
    this.onInteractionEnd,
  });

  @override
  State<PlayerGestureOverlay> createState() => _PlayerGestureOverlayState();
}

class _SeekHudData {
  final int pos, dur;
  final bool fwd;
  const _SeekHudData(this.pos, this.dur, this.fwd);
}

class _PlayerGestureOverlayState extends State<PlayerGestureOverlay> {
  final ValueNotifier<double?> _hudBri = ValueNotifier(null);
  final ValueNotifier<double?> _hudVol = ValueNotifier(null);
  final ValueNotifier<_SeekHudData?> _hudSeek = ValueNotifier(null);
  Timer? _hudTimer;

  void _bump() {
    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(milliseconds: 1200), () {
      _hudBri.value = null;
      _hudVol.value = null;
      _hudSeek.value = null;
    });
  }

  void _onSeek(int pos, int dur, bool fwd) {
    _hudSeek.value = _SeekHudData(pos, dur, fwd);
    _hudBri.value = null;
    _hudVol.value = null;
    _bump();
    widget.onInteractionUpdate?.call();
  }

  void _onSeekEnd(int pos) {
    _hudSeek.value = null;
    unawaited(widget.player.seek(Duration(milliseconds: pos)));
    widget.onInteractionEnd?.call();
  }

  void _onBri(double v) {
    _hudBri.value = v;
    _hudVol.value = null;
    _hudSeek.value = null;
    _bump();
    widget.onInteractionUpdate?.call();
  }

  void _onVol(double v) {
    _hudVol.value = v;
    _hudBri.value = null;
    _hudSeek.value = null;
    _bump();
    widget.onInteractionUpdate?.call();
  }

  void _onPanStart() => widget.onInteractionStart?.call();

  @override
  void dispose() {
    _hudTimer?.cancel();
    _hudBri.dispose();
    _hudVol.dispose();
    _hudSeek.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final h = c.maxHeight;
      return Stack(children: [
        widget.child,
        Positioned.fill(
          child: _ThrottledPan(
            player: widget.player,
            width: w,
            height: h,
            onTap: widget.onTap,
            onDoubleTapLeft: widget.onDoubleTapLeft,
            onDoubleTapRight: widget.onDoubleTapRight,
            onPanStart: _onPanStart,
            onSeek: _onSeek,
            onSeekEnd: _onSeekEnd,
            onBrightness: _onBri,
            onVolume: _onVol,
          ),
        ),
        // HUDs — только они перестраиваются, видео не трогаем
        ValueListenableBuilder<double?>(
          valueListenable: _hudBri,
          builder: (_, v, __) => v == null
              ? const SizedBox.shrink()
              : Positioned(left: 24, top: 0, bottom: 0, child: Center(child: _IndicatorBar(icon: Icons.light_mode, value: v, color: Colors.white))),
        ),
        ValueListenableBuilder<double?>(
          valueListenable: _hudVol,
          builder: (_, v, __) => v == null
              ? const SizedBox.shrink()
              : Positioned(right: 24, top: 0, bottom: 0, child: Center(child: _IndicatorBar(icon: Icons.volume_up, value: v, color: const Color(0xFF00E5FF)))),
        ),
        ValueListenableBuilder<_SeekHudData?>(
          valueListenable: _hudSeek,
          builder: (_, d, __) => d == null
              ? const SizedBox.shrink()
              : Positioned(left: 32, right: 32, bottom: 32, child: _SeekHud(pos: d.pos, dur: d.dur, fwd: d.fwd)),
        ),
      ]);
    });
  }
}

/// Один GestureDetector на весь экран — без конкуренции арен.
/// Троттлинг: seek 30мс, bright/vol 50мс, fire-and-forget на мост.
class _ThrottledPan extends StatefulWidget {
  final PlayerController player;
  final double width, height;
  final VoidCallback onTap;
  final VoidCallback onDoubleTapLeft;
  final VoidCallback onDoubleTapRight;
  final VoidCallback? onPanStart;
  final void Function(int pos, int dur, bool fwd) onSeek;
  final void Function(int pos) onSeekEnd;
  final void Function(double v) onBrightness;
  final void Function(double v) onVolume;
  const _ThrottledPan({
    required this.player,
    required this.width,
    required this.height,
    required this.onTap,
    required this.onDoubleTapLeft,
    required this.onDoubleTapRight,
    this.onPanStart,
    required this.onSeek,
    required this.onSeekEnd,
    required this.onBrightness,
    required this.onVolume,
  });
  @override
  State<_ThrottledPan> createState() => _ThrottledPanState();
}

class _ThrottledPanState extends State<_ThrottledPan> {
  Offset? _start;
  int? _dragType; // null=не решено, 1=seek, 2=bright, 3=vol
  double _accX = 0, _accY = 0;
  int _startPos = 0;
  double _startBri = 0.5, _startVol = 0, _maxVol = 15;
  bool _seekFwd = true;

  // троттлинг
  int _lastSeekMs = 0;
  int _lastBriMs = 0;
  int _lastVolMs = 0;

  bool get _isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onTap,
      onDoubleTapDown: (d) {
        final x = d.localPosition.dx;
        if (x < widget.width * 0.4) widget.onDoubleTapLeft();
        else if (x > widget.width * 0.6) widget.onDoubleTapRight();
        else widget.onTap();
      },
      onPanStart: (d) {
        widget.onPanStart?.call();
        _start = d.localPosition;
        _accX = 0;
        _accY = 0;
        _dragType = null;
        final isSeekZone = d.localPosition.dy > widget.height * 0.75;
        if (isSeekZone) {
          // seek — сразу фиксируем тип 0→1, без асинхрона
          _dragType = 0;
          _startPos = widget.player.position.inMilliseconds;
        } else if (!_isDesktop) {
          // для bright/vol — грузим старт-значения без await в build-цикле
          // fire-and-forget: к моменту первого move они уже будут
          NativeBridge.getBrightness().then((v) => _startBri = v).catchError((_) => _startBri = 0.5);
          NativeBridge.getVolume().then((m) {
            _startVol = (m['cur'] as int).toDouble();
            _maxVol = (m['max'] as int).toDouble();
          }).catchError((_) {});
        } else {
          // desktop — игнорируем вертикаль
          _startPos = widget.player.position.inMilliseconds;
        }
      },
      onPanUpdate: (d) {
        if (_start == null) return;
        _accX += d.delta.dx;
        _accY += d.delta.dy;
        const slop = 14.0;
        if (_dragType == null) {
          if (_accX.abs() < slop && _accY.abs() < slop) return;
          final isSeekZone = _start!.dy > widget.height * 0.75;
          if (isSeekZone) {
            _dragType = 1;
          } else {
            if (_isDesktop) return; // на ПК вертикаль не нужна
            if (_accY.abs() > _accX.abs()) {
              _dragType = _start!.dx < widget.width / 2 ? 2 : 3;
            } else {
              return;
            }
          }
        }
        // если ещё не решили (0) — ждём горизонтального движения
        if (_dragType == 0) {
          if (_accX.abs() < slop) return;
          _dragType = 1;
        }

        final now = DateTime.now().millisecondsSinceEpoch;

        if (_dragType == 1) {
          if (now - _lastSeekMs < 30) return;
          _lastSeekMs = now;
          final dur = widget.player.duration.inMilliseconds;
          if (dur <= 0) return;
          // как в Compose: 5мин максимум сдвига на ширину
          final maxSpan = math.min(dur, 300000);
          final delta = ((_accX / widget.width) * maxSpan).round();
          final target = (_startPos + delta).clamp(0, dur);
          _seekFwd = delta >= 0;
          widget.onSeek(target, dur, _seekFwd);
        } else if (_dragType == 2) {
          if (_isDesktop) return;
          if (now - _lastBriMs < 50) return;
          _lastBriMs = now;
          final diff = -(_accY / widget.height) * 1.5;
          final nb = (_startBri + diff).clamp(0.0, 1.0);
          // fire-and-forget, не await — не забиваем стек
          unawaited(NativeBridge.setBrightness(nb));
          widget.onBrightness(nb);
        } else if (_dragType == 3) {
          if (_isDesktop) return;
          if (now - _lastVolMs < 50) return;
          _lastVolMs = now;
          final diff = -(_accY / widget.height) * _maxVol * 1.5;
          final nv = (_startVol + diff).clamp(0, _maxVol);
          unawaited(NativeBridge.setVolume(nv.round()));
          // синхронизируем внутренний volume плеера без await
          // используем прямой вызов, но не ждём
          unawaited(widget.player.setVolume((nv / _maxVol) * 100));
          widget.onVolume(nv / _maxVol);
        }
      },
      onPanEnd: (_) {
        if (_dragType == 1) {
          final dur = widget.player.duration.inMilliseconds;
          if (dur > 0) {
            final maxSpan = math.min(dur, 300000);
            final delta = ((_accX / widget.width) * maxSpan).round();
            final target = (_startPos + delta).clamp(0, dur);
            widget.onSeekEnd(target);
          }
        }
        _start = null;
        _dragType = null;
      },
      onPanCancel: () {
        _start = null;
        _dragType = null;
      },
      child: const ColoredBox(color: Colors.transparent),
    );
  }
}

class _IndicatorBar extends StatelessWidget {
  final IconData icon; final double value; final Color color;
  const _IndicatorBar({required this.icon, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44, height: 180,
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withOpacity(0.15))),
      child: Stack(children: [
        Positioned.fill(child: Align(alignment: Alignment.bottomCenter, child: FractionallySizedBox(heightFactor: value.clamp(0,1), child: Container(decoration: BoxDecoration(color: color.withOpacity(0.8), borderRadius: BorderRadius.circular(22)))))),
        Positioned(top: 10, left: 0, right: 0, child: Icon(icon, color: Colors.white, size: 24)),
      ]),
    );
  }
}

class _SeekHud extends StatelessWidget {
  final int pos, dur; final bool fwd;
  const _SeekHud({required this.pos, required this.dur, required this.fwd});
  @override
  Widget build(BuildContext context) {
    final prog = dur>0 ? (pos/dur).clamp(0.0,1.0) : 0.0;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [Icon(fwd ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded, size: 14, color: const Color(0xFF00E5FF)), const SizedBox(width: 4), Text(_fmtMs(pos), style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 14))]),
        Text(_fmtMs(dur), style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: Container(height: 8, color: Colors.white.withOpacity(0.2), child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: prog, child: Container(color: const Color(0xFF00E5FF))))),
    ]);
  }
}
