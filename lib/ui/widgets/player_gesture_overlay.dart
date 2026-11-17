import 'dart:async';
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

/// Порт твоего Compose PlayerGestureOverlay на Flutter
/// Тап — показать/скрыть, дабл-тап лево/право — ±10с, свайпы: низ 25% — перемотка, лево — яркость, право — громкость
class PlayerGestureOverlay extends StatefulWidget {
  final Widget child;
  final PlayerController player;
  final VoidCallback onTap;
  final VoidCallback onDoubleTapLeft;
  final VoidCallback onDoubleTapRight;
  const PlayerGestureOverlay({
    super.key,
    required this.child,
    required this.player,
    required this.onTap,
    required this.onDoubleTapLeft,
    required this.onDoubleTapRight,
  });

  @override
  State<PlayerGestureOverlay> createState() => _PlayerGestureOverlayState();
}

class _PlayerGestureOverlayState extends State<PlayerGestureOverlay> {
  double? _hudVol;
  double? _hudBri;
  int? _hudSeekPos;
  int? _hudSeekDur;
  bool _seekFwd = true;
  Timer? _hudTimer;

  void _bumpHud() {
    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() { _hudVol = null; _hudBri = null; _hudSeekPos = null; });
    });
  }

  @override
  void dispose() { _hudTimer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onTap,
        onDoubleTapDown: (d) {
          final x = d.localPosition.dx;
          if (x < w * 0.4) widget.onDoubleTapLeft();
          else if (x > w * 0.6) widget.onDoubleTapRight();
          else widget.onTap();
        },
        onPanStart: (d) async {
          // bottom 25% — seek, иначе brightness/volume
          final isSeek = d.localPosition.dy > h * 0.75;
          // Сохраняем начальные значения
          if (!isSeek) {
            // Для вертикали — запомним старт
            // brightness/volume старта берём асинхронно, но можно синхронно
          }
        },
        child: Stack(children: [
          widget.child,
          // Вертикаль/горизонталь — через Pan с логикой как в Compose
          Positioned.fill(
            child: _PanHandler(
              onSeek: (pos, dur, fwd) => setState(() { _hudSeekPos = pos; _hudSeekDur = dur; _seekFwd = fwd; _hudBri=null; _hudVol=null; _bumpHud(); }),
              onSeekEnd: (pos) { setState(() => _hudSeekPos=null); widget.player.seek(Duration(milliseconds: pos)); },
              onBrightness: (v) => setState(() { _hudBri = v; _hudVol=null; _bumpHud(); }),
              onVolume: (v) => setState(() { _hudVol = v; _hudBri=null; _bumpHud(); }),
              player: widget.player,
              width: w, height: h,
            ),
          ),
          // HUDs — как в Compose
          if (_hudBri != null)
            Positioned(left: 24, top: 0, bottom: 0, child: Center(child: _IndicatorBar(icon: Icons.light_mode, value: _hudBri!, color: Colors.white))),
          if (_hudVol != null)
            Positioned(right: 24, top: 0, bottom: 0, child: Center(child: _IndicatorBar(icon: Icons.volume_up, value: _hudVol!, color: const Color(0xFF00E5FF)))),
          if (_hudSeekPos != null && _hudSeekDur != null)
            Positioned(
              left: 32, right: 32, bottom: 32,
              child: _SeekHud(pos: _hudSeekPos!, dur: _hudSeekDur!, fwd: _seekFwd),
            ),
        ]),
      );
    });
  }
}

class _PanHandler extends StatefulWidget {
  final void Function(int pos, int dur, bool fwd) onSeek;
  final void Function(int pos) onSeekEnd;
  final void Function(double v) onBrightness;
  final void Function(double v) onVolume;
  final PlayerController player;
  final double width, height;
  const _PanHandler({required this.onSeek, required this.onSeekEnd, required this.onBrightness, required this.onVolume, required this.player, required this.width, required this.height});
  @override
  State<_PanHandler> createState() => _PanHandlerState();
}
class _PanHandlerState extends State<_PanHandler> {
  Offset? _start;
  int? _dragType; // 1 seek, 2 bri, 3 vol
  double _accX=0, _accY=0;
  int _startPos=0, _dur=0;
  double _startBri=0.5, _startVol=0;
  double _maxVol=15;
  bool _seekFwd=true;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (d) async {
        _start = d.localPosition;
        _accX=0; _accY=0; _dragType=null;
        final isSeek = d.localPosition.dy > widget.height*0.75;
        if (isSeek) {
          _dragType = 0; // undecided but seek zone
          _startPos = widget.player.position.inMilliseconds;
          _dur = widget.player.duration.inMilliseconds;
        } else {
          // preload
          try { _startBri = await NativeBridge.getBrightness(); } catch(_){ _startBri=0.5; }
          try { final m= await NativeBridge.getVolume(); _startVol = m['cur']!.toDouble(); _maxVol = m['max']!.toDouble(); } catch(_){}
        }
      },
      onPanUpdate: (d) async {
        if (_start==null) return;
        _accX += d.delta.dx;
        _accY += d.delta.dy;
        const slop = 12.0;
        if (_dragType==null) {
          if (_accX.abs() < slop && _accY.abs() < slop) return;
          final isSeekZone = _start!.dy > widget.height*0.75;
          if (isSeekZone) { _dragType=1; }
          else {
            if (_accY.abs() > _accX.abs()) {
              _dragType = _start!.dx < widget.width/2 ? 2 : 3;
            } else { return; }
          }
        }
        if (_dragType==1) {
          final dur = widget.player.duration.inMilliseconds;
          if (dur<=0) return;
          final maxSpan = dur < 300000 ? dur : 300000;
          final delta = ((_accX / widget.width) * maxSpan).round();
          final target = (_startPos + delta).clamp(0, dur);
          _seekFwd = delta>=0;
          widget.onSeek(target, dur, _seekFwd);
        } else if (_dragType==2) {
          final diff = -(_accY / widget.height)*1.5;
          final nb = (_startBri + diff).clamp(0.0, 1.0);
          await NativeBridge.setBrightness(nb);
          widget.onBrightness(nb);
        } else if (_dragType==3) {
          final diff = -(_accY / widget.height)*_maxVol*1.5;
          final nv = (_startVol + diff).clamp(0, _maxVol);
          await NativeBridge.setVolume(nv.round());
          widget.onVolume(nv/_maxVol);
        }
      },
      onPanEnd: (d) {
        if (_dragType==1) {
          // seek commit handled via last hud value
          // we need to find last target — store it
          final dur = widget.player.duration.inMilliseconds;
          final maxSpan = dur < 300000 ? dur : 300000;
          final delta = ((_accX / widget.width) * maxSpan).round();
          final target = (_startPos + delta).clamp(0, dur);
          if (dur>0) widget.onSeekEnd(target);
        }
        _start=null; _dragType=null;
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
        Text(_fmtMs(pos), style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 14)),
        Text(_fmtMs(dur), style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: Container(height: 8, color: Colors.white.withOpacity(0.2), child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: prog, child: Container(color: const Color(0xFF00E5FF))))),
    ]);
  }
}
