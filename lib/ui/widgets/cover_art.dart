import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../services/library.dart';

/// Обложка трека: из ID3-тегов / MediaStore или стильная заглушка.
class CoverArt extends ConsumerWidget {
  final MediaTrack track;
  final double size;
  final double radius;

  const CoverArt({
    super.key,
    required this.track,
    this.size = 48,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = ref.watch(libraryProvider);
    final bytes = lib.coverOf(track);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    Widget inner;
    if (bytes != null) {
      inner = Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: size,
        height: size,
        gaplessPlayback: true,
      );
    } else {
      inner = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withOpacity(0.75),
              accent.withOpacity(0.25),
            ],
          ),
        ),
        child: Icon(
          track.isVideo ? Icons.movie_outlined : Icons.music_note_rounded,
          color: Colors.white,
          size: size * 0.5,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: inner,
    );
  }
}
