import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  final int defaultExpandedDepth;

  const Settings({this.defaultExpandedDepth = 1});

  Settings copyWith({int? defaultExpandedDepth}) {
    return Settings(
      defaultExpandedDepth: defaultExpandedDepth ?? this.defaultExpandedDepth,
    );
  }
}

class SettingsNotifier extends StateNotifier<Settings> {
  static const _keyDefaultDepth = 'default_expanded_depth';

  SettingsNotifier() : super(const Settings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final depth = prefs.getInt(_keyDefaultDepth) ?? state.defaultExpandedDepth;
    state = state.copyWith(defaultExpandedDepth: depth);
  }

  Future<void> setDefaultExpandedDepth(int depth) async {
    state = state.copyWith(defaultExpandedDepth: depth);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDefaultDepth, depth);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, Settings>((
  ref,
) {
  return SettingsNotifier();
});
