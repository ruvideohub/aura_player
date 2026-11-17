import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

enum RepeatMode { off, all, one }

enum VisualizerMode { bars, wave, orb }

class SettingsController extends ChangeNotifier {
  static const _key = 'aura.settings.v2';

  ThemeMode themeMode = ThemeMode.dark;
  int accentIndex = 0;
  VisualizerMode visualizerMode = VisualizerMode.bars;
  double visualizerOpacity = 0.85;
  bool miniViz = true;
  bool eqEnabled = true;
  String eqPresetKey = 'flat';
  List<double> eqGains = List.filled(10, 0.0);
  int bassBoost = 0; // 0..1000, 0=выкл, 500=50% — системный BassBoost
  List<String> scanDirs = [];
  bool restorePositions = true;

  final SharedPreferences _prefs;

  SettingsController(this._prefs) {
    _load();
  }

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      themeMode =
          ThemeMode.values[j['themeMode'] as int? ?? ThemeMode.dark.index];
      accentIndex = j['accentIndex'] as int? ?? 0;
      visualizerMode =
          VisualizerMode.values[j['visualizerMode'] as int? ?? 0];
      visualizerOpacity =
          (j['visualizerOpacity'] as num?)?.toDouble() ?? 0.85;
      miniViz = j['miniViz'] as bool? ?? true;
      eqEnabled = j['eqEnabled'] as bool? ?? true;
      eqPresetKey = j['eqPresetKey'] as String? ?? 'flat';
      final g = (j['eqGains'] as List?)
          ?.map((e) => (e as num).toDouble())
          .toList();
      if (g != null && g.length == 10) eqGains = g;
      scanDirs = (j['scanDirs'] as List?)?.cast<String>().toList() ?? [];
      bassBoost = (j['bassBoost'] as int?) ?? 0;
      restorePositions = j['restorePositions'] as bool? ?? true;
    } catch (_) {
      // битые настройки — используем значения по умолчанию
    }
  }

  Future<void> _save() async {
    try {
      await _prefs.setString(_key, jsonEncode({
        'themeMode': themeMode.index,
        'accentIndex': accentIndex,
        'visualizerMode': visualizerMode.index,
        'visualizerOpacity': visualizerOpacity,
        'miniViz': miniViz,
        'eqEnabled': eqEnabled,
        'eqPresetKey': eqPresetKey,
        'eqGains': eqGains,
        'scanDirs': scanDirs,
        'bassBoost': bassBoost,
        'restorePositions': restorePositions,
      }));
    } catch (_) {}
  }

  void setThemeMode(ThemeMode v) {
    themeMode = v;
    _save();
    notifyListeners();
  }

  void setAccent(int i) {
    accentIndex = i;
    _save();
    notifyListeners();
  }

  void setVisualizerMode(VisualizerMode v) {
    visualizerMode = v;
    _save();
    notifyListeners();
  }

  void setVisualizerOpacity(double v) {
    visualizerOpacity = v;
    _save();
    notifyListeners();
  }

  void setMiniViz(bool v) {
    miniViz = v;
    _save();
    notifyListeners();
  }

  void setEqEnabled(bool v) {
    eqEnabled = v;
    _save();
    notifyListeners();
  }

  void setEqGains(List<double> g, {String? presetKey}) {
    if (g.length != 10) return;
    eqGains = List.of(g);
    eqPresetKey = presetKey ?? 'custom';
    _save();
    notifyListeners();
  }

  void applyPreset(EqPreset p) {
    setEqGains(p.gains, presetKey: p.key);
  }

  void setBassBoost(int v) {
    bassBoost = v.clamp(0, 1000);
    _save();
    notifyListeners();
  }

  void addScanDir(String dir) {
    if (dir.isEmpty || scanDirs.contains(dir)) return;
    scanDirs = [...scanDirs, dir];
    _save();
    notifyListeners();
  }

  void removeScanDir(String dir) {
    scanDirs = scanDirs.where((d) => d != dir).toList();
    _save();
    notifyListeners();
  }

  void setRestorePositions(bool v) {
    restorePositions = v;
    _save();
    notifyListeners();
  }
}

/// Создаётся в main() через override с готовым SharedPreferences.
final settingsProvider = ChangeNotifierProvider<SettingsController>((ref) {
  throw UnimplementedError('settingsProvider переопределяется в main()');
});
