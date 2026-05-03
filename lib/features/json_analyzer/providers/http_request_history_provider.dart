import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/http_request_entry.dart';

/// Immutable state for the HTTP request history + saved requests feature.
@immutable
class HttpRequestHistoryState {
  /// Recent (unnamed) requests, most recent first. Capped at [_maxHistory].
  final List<HttpRequestEntry> history;

  /// User-saved (named) requests, most recently saved first.
  final List<HttpRequestEntry> saved;

  const HttpRequestHistoryState({
    this.history = const [],
    this.saved = const [],
  });

  HttpRequestHistoryState copyWith({
    List<HttpRequestEntry>? history,
    List<HttpRequestEntry>? saved,
  }) {
    return HttpRequestHistoryState(
      history: history ?? this.history,
      saved: saved ?? this.saved,
    );
  }
}

class HttpRequestHistoryNotifier
    extends StateNotifier<HttpRequestHistoryState> {
  static const _keyHistory = 'http_request_history_v1';
  static const _keySaved = 'http_request_saved_v1';
  static const _maxHistory = 20;
  static const _maxSaved = 50;

  HttpRequestHistoryNotifier() : super(const HttpRequestHistoryState()) {
    _load();
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = HttpRequestHistoryState(
      history: _decodeList(prefs.getString(_keyHistory)),
      saved: _decodeList(prefs.getString(_keySaved)),
    );
  }

  List<HttpRequestEntry> _decodeList(String? raw) {
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => HttpRequestEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(
        _keyHistory,
        jsonEncode(state.history.map((e) => e.toJson()).toList()),
      ),
      prefs.setString(
        _keySaved,
        jsonEncode(state.saved.map((e) => e.toJson()).toList()),
      ),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Public actions
  // ---------------------------------------------------------------------------

  /// Adds [entry] to recent history, deduplicating by URL + method.
  /// Trims list to [_maxHistory] items.
  Future<void> addToHistory(HttpRequestEntry entry) async {
    final updated = [
      entry,
      ...state.history.where(
        (e) => e.url != entry.url || e.method != entry.method,
      ),
    ].take(_maxHistory).toList();

    state = state.copyWith(history: updated);
    await _persist();
  }

  /// Saves [entry] under [name].
  ///
  /// If an entry with the same URL + method already exists in [saved],
  /// it is replaced rather than duplicated.
  Future<void> saveRequest(HttpRequestEntry entry, String name) async {
    final named = entry.copyWith(name: name);
    final updated = [
      named,
      ...state.saved.where(
        (e) => e.url != entry.url || e.method != entry.method,
      ),
    ].take(_maxSaved).toList();
    state = state.copyWith(saved: updated);
    await _persist();
  }

  /// Renames an existing saved entry.
  Future<void> renameEntry(String id, String newName) async {
    final updated = state.saved
        .map((e) => e.id == id ? e.copyWith(name: newName) : e)
        .toList();
    state = state.copyWith(saved: updated);
    await _persist();
  }

  Future<void> deleteHistory(String id) async {
    state = state.copyWith(
      history: state.history.where((e) => e.id != id).toList(),
    );
    await _persist();
  }

  Future<void> deleteSaved(String id) async {
    state = state.copyWith(
      saved: state.saved.where((e) => e.id != id).toList(),
    );
    await _persist();
  }

  Future<void> clearHistory() async {
    state = state.copyWith(history: const []);
    await _persist();
  }
}

final httpRequestHistoryProvider =
    StateNotifierProvider<HttpRequestHistoryNotifier, HttpRequestHistoryState>(
      (ref) => HttpRequestHistoryNotifier(),
    );
