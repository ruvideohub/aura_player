import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../services/native_bridge.dart';

class VideoThumb extends StatefulWidget {
  final String path;
  final double? width, height;
  const VideoThumb({super.key, required this.path, this.width, this.height});

  @override
  State<VideoThumb> createState() => _VideoThumbState();
}

class _ThumbCache {
  static final Map<String, Uint8List?> _mem = {};
  static Uint8List? get(String k) => _mem[k];
  static void set(String k, Uint8List? v) {
    if (_mem.length > 240) _mem.clear();
    _mem[k] = v;
  }
}

// Очередь — не более 3 параллельных миниатюр, чтобы не забивать диск/декодер на ПК
class _ThumbQueue {
  static int _running = 0;
  static const _max = 3;
  static final List<Completer<void>> _waiters = [];
  static Future<void> acquire() async {
    if (_running < _max) { _running++; return; }
    final c = Completer<void>();
    _waiters.add(c);
    await c.future;
    _running++;
  }
  static void release() {
    _running--;
    if (_waiters.isNotEmpty) {
      final w = _waiters.removeAt(0);
      if (!w.isCompleted) w.complete();
    }
  }
}

class _VideoThumbState extends State<VideoThumb> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VideoThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _loading = true;
      _bytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    final cached = _ThumbCache.get(widget.path);
    if (cached != null) {
      if (!mounted) return;
      setState(() { _bytes = cached; _loading = false; });
      return;
    }
    if (_ThumbCache._mem.containsKey(widget.path)) {
      if (!mounted) return;
      setState(() { _loading = false; });
      return;
    }
    await _ThumbQueue.acquire();
    try {
      final b = await NativeBridge.videoThumb(widget.path);
      _ThumbCache.set(widget.path, b);
      if (!mounted) return;
      setState(() { _bytes = b; _loading = false; });
    } finally {
      _ThumbQueue.release();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(color: Color(0xFF1A1A1A), child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))));
    }
    if (_bytes != null) {
      return RepaintBoundary(child: Image.memory(_bytes!, width: widget.width, height: widget.height, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_,__,___) => _fallback()));
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: widget.width, height: widget.height,
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Theme.of(context).colorScheme.primary.withOpacity(0.85), Theme.of(context).colorScheme.primary.withOpacity(0.3)])),
      child: const Center(child: Icon(Icons.play_circle_fill_rounded, size: 48, color: Colors.white)),
    );
  }
}
