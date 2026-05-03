import 'dart:convert';

import 'package:http/http.dart' as http;

import 'version_info.dart';

class VersionService {
  // Supplied API (Supabase REST)
  static const _endpoint =
      "https://lezadwcqeaufwdnxntoe.supabase.co/rest/v1/jsonlens?select=version,release_notes,%20download_at,created_at&order=version.desc&limit=1";
  // Publishable (anon) key — safe for client-side use but can be overridden
  // at compile time with --dart-define=SUPABASE_ANON_KEY=<value>.
  static const _apiKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_yPx-x3qexCa56EMkbtw0mw_6b8ma8Tc',
  );

  Future<VersionInfo?> fetchLatest() async {
    final r = await http.get(
      Uri.parse(_endpoint),
      headers: {'apikey': _apiKey, 'Accept': 'application/json'},
    );

    if (r.statusCode != 200) return null;
    final List<dynamic> arr = jsonDecode(r.body) as List<dynamic>;
    if (arr.isEmpty) return null;
    final m = arr.first as Map<String, dynamic>;
    return VersionInfo.fromJson(m);
  }
}
