import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'version_info.dart';
import 'version_service.dart';

final versionNotifierProvider =
    StateNotifierProvider<VersionNotifier, VersionState>((ref) {
      return VersionNotifier(ref);
    });

/// Helper to trigger a check manually (e.g., from About or on resume)
final versionCheckTriggerProvider = Provider(
  (ref) => ref.read(versionNotifierProvider.notifier),
);

class VersionState {
  final VersionInfo? info;
  final bool checking;
  final bool hasNew;

  VersionState({this.info, this.checking = false, this.hasNew = false});

  VersionState copyWith({VersionInfo? info, bool? checking, bool? hasNew}) {
    return VersionState(
      info: info ?? this.info,
      checking: checking ?? this.checking,
      hasNew: hasNew ?? this.hasNew,
    );
  }
}

class VersionNotifier extends StateNotifier<VersionState> {
  final VersionService _service = VersionService();
  static const _cacheKey = 'version_info_json';
  static const _cacheTsKey = 'version_info_ts';
  static const _cacheTtlSeconds = 3600; // 1 hour

  VersionNotifier(Ref ref) : super(VersionState()) {
    // Do not block constructor; start check in background
    _checkCachedThenFetch();
  }

  Future<void> _checkCachedThenFetch() async {
    await _loadFromCache();
    await checkForUpdateIfConnected();
  }

  Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    final ts = prefs.getInt(_cacheTsKey);
    if (raw != null && ts != null) {
      final info = VersionInfo.fromJsonString(raw);
      if (info != null) {
        state = state.copyWith(
          info: info,
          checking: false,
          hasNew: await _isNewer(info),
        );
      }
    }
  }

  Future<void> checkForUpdateIfConnected({bool force = false}) async {
    // If cached and not expired and not forced, do nothing
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_cacheTsKey);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (!force && ts != null && (now - ts) < _cacheTtlSeconds) return;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return; // no network

    await checkForUpdate();
  }

  Future<void> checkForUpdate() async {
    try {
      state = state.copyWith(checking: true);
      final info = await _service.fetchLatest();
      if (info != null) {
        await _saveToCache(info);
        final isNew = await _isNewer(info);
        state = state.copyWith(info: info, checking: false, hasNew: isNew);
      } else {
        state = state.copyWith(checking: false);
      }
    } catch (e) {
      state = state.copyWith(checking: false);
    }
  }

  /// Compare two version strings a and b.
  /// Returns 1 if a > b, -1 if a < b, 0 if equal.
  static int compareVersions(String a, String b) {
    final aParts = a.split('.').map(int.tryParse).map((v) => v ?? 0).toList();
    final bParts = b.split('.').map(int.tryParse).map((v) => v ?? 0).toList();
    final len = aParts.length > bParts.length ? aParts.length : bParts.length;
    for (var i = 0; i < len; i++) {
      final av = (i < aParts.length) ? aParts[i] : 0;
      final bv = (i < bParts.length) ? bParts[i] : 0;
      if (av > bv) return 1;
      if (av < bv) return -1;
    }
    return 0;
  }

  Future<bool> _isNewer(VersionInfo info) async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      final current = pkg.version;
      return compareVersions(info.latestVersion, current) > 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveToCache(VersionInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, info.toJsonString());
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await prefs.setInt(_cacheTsKey, now);
  }
}
