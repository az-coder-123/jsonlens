import 'dart:convert';

import 'package:http/http.dart' as http;

import 'version_info.dart';

class VersionService {
  // Supplied API (Supabase REST)
  static const _endpoint =
      "https://lezadwcqeaufwdnxntoe.supabase.co/rest/v1/jsonlens?select=version,release_notes,%20download_at,created_at&order=version.desc&limit=1";
  // Provided key (public) — in a real app use a server-side proxy or secured key
  static const _apiKey = 'sb_publishable_yPx-x3qexCa56EMkbtw0mw_6b8ma8Tc';

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
