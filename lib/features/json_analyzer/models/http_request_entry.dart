/// A single HTTP request entry — used for both recent history and saved requests.
class HttpRequestEntry {
  final String id;

  /// Human-readable label. Non-null for saved (starred) entries; null for
  /// plain history entries.
  final String? name;

  final String url;
  final String method;
  final Map<String, String> headers;
  final String body;
  final DateTime timestamp;

  const HttpRequestEntry({
    required this.id,
    this.name,
    required this.url,
    required this.method,
    required this.headers,
    required this.body,
    required this.timestamp,
  });

  /// Whether this entry has been explicitly saved with a user-defined [name].
  bool get isSaved => name != null;

  HttpRequestEntry copyWith({String? name}) {
    return HttpRequestEntry(
      id: id,
      name: name ?? this.name,
      url: url,
      method: method,
      headers: Map<String, String>.from(headers),
      body: body,
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'method': method,
    'headers': headers,
    'body': body,
    'timestamp': timestamp.toIso8601String(),
  };

  factory HttpRequestEntry.fromJson(Map<String, dynamic> json) {
    return HttpRequestEntry(
      id: json['id'] as String,
      name: json['name'] as String?,
      url: json['url'] as String,
      method: json['method'] as String,
      headers: Map<String, String>.from((json['headers'] as Map?) ?? {}),
      body: (json['body'] as String?) ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  /// Creates a new entry with a generated [id] and the current timestamp.
  factory HttpRequestEntry.create({
    String? name,
    required String url,
    required String method,
    required Map<String, String> headers,
    required String body,
  }) {
    return HttpRequestEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      url: url,
      method: method,
      headers: headers,
      body: body,
      timestamp: DateTime.now(),
    );
  }
}
