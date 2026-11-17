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
    final b = await NativeBridge.videoThumb(widget.path);
    if (!mounted) return;
    setState(() { _bytes = b; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(color: Colors.black12, child: const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))));
    }
    if (_bytes != null) {
      return Image.memory(_bytes!, width: widget.width, height: widget.height, fit: BoxFit.cover,
        errorBuilder: (_,__,___) => _fallback(),
      );
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
