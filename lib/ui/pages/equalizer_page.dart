import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../services/native_bridge.dart';
import '../../services/settings.dart';
import '../../state/player_controller.dart';

class EqualizerPage extends ConsumerWidget {
  const EqualizerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    void apply() {
      ref.read(playerProvider).applyEqualizer();
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.equalizer_rounded, color: accent),
                          const SizedBox(width: 10),
                          Text(
                            'Эквалайзер',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            settings.eqEnabled ? 'Включён' : 'Обход',
                            style: TextStyle(
                              fontSize: 13,
                              color: settings.eqEnabled
                                  ? accent
                                  : theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                            ),
                          ),
                          Switch(
                            value: settings.eqEnabled,
                            onChanged: (v) {
                              settings.setEqEnabled(v);
                              apply();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '10-полосный эквалайзер применяется в реальном времени. '
                        '${NativeBridge.isAndroid ? 'Движок: системный audiofx (Kotlin).' : 'Движок: mpv firequalizer.'}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color:
                              theme.colorScheme.onSurface.withOpacity(0.55),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in eqPresets)
                            ChoiceChip(
                              label: Text(p.label),
                              selected: settings.eqPresetKey == p.key,
                              onSelected: (_) {
                                settings.applyPreset(p);
                                apply();
                              },
                              selectedColor: accent.withOpacity(0.2),
                              labelStyle: TextStyle(
                                color: settings.eqPresetKey == p.key
                                    ? accent
                                    : null,
                                fontWeight: settings.eqPresetKey == p.key
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          if (settings.eqPresetKey == 'custom')
                            ChoiceChip(
                              label: const Text('Своя настройка'),
                              selected: true,
                              onSelected: (_) {},
                              selectedColor: accent.withOpacity(0.2),
                              labelStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Вместо GridView — Column, чтобы не ломать hit-test на Android
                      Column(
                        children: [
                          for (var i = 0; i < 10; i++)
                            Builder(builder: (context) {
                              final g = settings.eqGains[i];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 58,
                                      child: Text(
                                        fmtFreq(eqFrequencies[i]),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.6),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Slider(
                                        min: -12,
                                        max: 12,
                                        divisions: 24,
                                        value: g,
                                        label: fmtGain(g),
                                        onChanged: settings.eqEnabled
                                            ? (v) {
                                                final list = List.of(settings.eqGains);
                                                list[i] = v;
                                                settings.setEqGains(list);
                                                apply();
                                              }
                                            : null,
                                        activeColor: accent,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 58,
                                      child: Text(
                                        fmtGain(g),
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures()
                                          ],
                                          color: g != 0
                                              ? accent
                                              : theme.colorScheme.onSurface
                                                  .withOpacity(0.55),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                      // Bass Boost — системный (Android audiofx)
                      if (NativeBridge.isAndroid) ...[
                        const Divider(height: 24),
                        Row(
                          children: [
                            Icon(Icons.speaker_rounded, size: 18, color: accent),
                            const SizedBox(width: 8),
                            const Text('Bass Boost', style: TextStyle(fontWeight: FontWeight.w600)),
                            const Spacer(),
                            Text('${(settings.bassBoost / 10).round()}%', style: TextStyle(fontSize: 12, color: settings.bassBoost == 0 ? theme.colorScheme.onSurface.withOpacity(0.5) : accent)),
                          ],
                        ),
                        Slider(
                          min: 0,
                          max: 1000,
                          divisions: 20,
                          value: settings.bassBoost.toDouble(),
                          label: '${(settings.bassBoost / 10).round()}%',
                          onChanged: (v) {
                            settings.setBassBoost(v.round());
                            apply();
                          },
                          activeColor: accent,
                        ),
                        Text('Усиливает низкие частоты (0 — выкл, 100% — максимум). Работает на Android.', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.5))),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              settings.applyPreset(eqPresets.first);
                              settings.setBassBoost(0);
                              apply();
                            },
                            icon: const Icon(Icons.restart_alt_rounded,
                                size: 18),
                            label: const Text('Сбросить'),
                          ),
                          const SizedBox(width: 12),
                          if (!NativeBridge.isAndroid && Platform.isWindows)
                            Expanded(
                              child: Text(
                                'Фильтр применяется к текущему и будущим трекам.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.45),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
