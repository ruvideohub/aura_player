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
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              MediaQuery.of(context).size.width > 760 ? 2 : 1,
                          childAspectRatio: 7.2,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 24,
                        ),
                        itemCount: 10,
                        itemBuilder: (context, i) {
                          final g = settings.eqGains[i];
                          return Row(
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
                                  onChanged: (v) {
                                    final list = List.of(settings.eqGains);
                                    list[i] = v;
                                    settings.setEqGains(list);
                                    apply();
                                  },
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
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              settings.applyPreset(eqPresets.first);
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
