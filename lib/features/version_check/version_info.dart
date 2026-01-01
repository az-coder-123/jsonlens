import 'dart:convert';

class VersionInfo {
  final String latestVersion;
  final String releaseNotes;
  final String? downloadAt;
  final DateTime? createdAt;

  VersionInfo({
    required this.latestVersion,
    required this.releaseNotes,
    this.downloadAt,
    this.createdAt,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(
      latestVersion: json['latest_version']?.toString() ?? '',
      releaseNotes: json['release_notes']?.toString() ?? '',
      downloadAt: json['download_at']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'latest_version': latestVersion,
    'release_notes': releaseNotes,
    'download_at': downloadAt,
    'created_at': createdAt?.toIso8601String(),
  };

  String toJsonString() => jsonEncode(toJson());

  static VersionInfo? fromJsonString(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return VersionInfo.fromJson(m);
    } catch (_) {
      return null;
    }
  }
}
