import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// The outcome status of a [JsonFetchResult].
enum FetchStatus {
  /// Request completed and the body is valid JSON.
  ok,

  /// Request completed but the server returned a non-2xx status code.
  httpError,

  /// The body is not valid JSON.
  invalidJson,

  /// The URL is malformed.
  invalidUrl,

  /// The request timed out.
  timeout,

  /// Any other network / socket error.
  networkError,
}

/// Result returned by [JsonFetcher.fetch].
class JsonFetchResult {
  final FetchStatus status;

  /// HTTP status code when available.
  final int? statusCode;

  /// Raw response body (may be empty on network errors).
  final String body;

  /// Parsed JSON data; non-null only when [status] == [FetchStatus.ok].
  final dynamic data;

  /// Human-readable error description; non-null on any error.
  final String? error;

  /// Response headers returned by the server. Empty on network-level errors.
  final Map<String, String> responseHeaders;

  const JsonFetchResult._({
    required this.status,
    this.statusCode,
    this.body = '',
    this.data,
    this.error,
    this.responseHeaders = const {},
  });

  bool get isOk => status == FetchStatus.ok;
}

/// Fetches JSON from an HTTP endpoint.
///
/// Supports GET, POST, PUT, PATCH, DELETE, HEAD, and OPTIONS with custom
/// headers. Times out after [timeout].
class JsonFetcher {
  static const Duration _defaultTimeout = Duration(seconds: 15);

  /// All HTTP methods supported by the fetcher.
  static const List<String> supportedMethods = [
    'GET',
    'POST',
    'PUT',
    'PATCH',
    'DELETE',
    'HEAD',
    'OPTIONS',
  ];

  /// Whether [method] typically sends a request body.
  static bool methodHasBody(String method) =>
      const {'POST', 'PUT', 'PATCH'}.contains(method.toUpperCase());

  /// Fetches [url] using [method] with optional [headers] and [body].
  ///
  /// Set [followRedirects] to `false` to treat 3xx responses as errors.
  /// Parses and validates the response as JSON.
  static Future<JsonFetchResult> fetch({
    required String url,
    String method = 'GET',
    Map<String, String> headers = const {},
    String body = '',
    Duration timeout = _defaultTimeout,
    bool followRedirects = true,
  }) async {
    final Uri uri;
    try {
      uri = Uri.parse(url.trim());
      if (!uri.hasScheme || (!uri.isScheme('http') && !uri.isScheme('https'))) {
        return const JsonFetchResult._(
          status: FetchStatus.invalidUrl,
          error: 'URL must start with http:// or https://',
        );
      }
    } on FormatException catch (e) {
      return JsonFetchResult._(
        status: FetchStatus.invalidUrl,
        error: 'Invalid URL: ${e.message}',
      );
    }

    final effectiveHeaders = {'Accept': 'application/json', ...headers};
    final client = http.Client();

    try {
      final upper = method.toUpperCase();
      final request = http.Request(upper, uri)
        ..followRedirects = followRedirects
        ..maxRedirects = followRedirects ? 5 : 0
        ..headers.addAll(effectiveHeaders);

      if (methodHasBody(upper) && body.isNotEmpty) request.body = body;

      final streamed = await client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return JsonFetchResult._(
          status: FetchStatus.httpError,
          statusCode: response.statusCode,
          body: response.body,
          responseHeaders: response.headers,
          error: 'Server returned HTTP ${response.statusCode}',
        );
      }

      // Decode body (handles UTF-8 with/without BOM).
      final responseBody = _decodeBody(response);

      dynamic parsed;
      try {
        parsed = jsonDecode(responseBody);
      } on FormatException catch (e) {
        return JsonFetchResult._(
          status: FetchStatus.invalidJson,
          statusCode: response.statusCode,
          body: responseBody,
          responseHeaders: response.headers,
          error: 'Response is not valid JSON: ${e.message}',
        );
      }

      return JsonFetchResult._(
        status: FetchStatus.ok,
        statusCode: response.statusCode,
        body: responseBody,
        data: parsed,
        responseHeaders: response.headers,
      );
    } on TimeoutException {
      return const JsonFetchResult._(
        status: FetchStatus.timeout,
        error: 'Request timed out. Try again or increase the timeout.',
      );
    } on SocketException catch (e) {
      return JsonFetchResult._(
        status: FetchStatus.networkError,
        error: 'Network error: ${e.message}',
      );
    } on http.ClientException catch (e) {
      return JsonFetchResult._(
        status: FetchStatus.networkError,
        error: 'Network error: ${e.message}',
      );
    } catch (e) {
      return JsonFetchResult._(
        status: FetchStatus.networkError,
        error: 'Unexpected error: $e',
      );
    } finally {
      client.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Decodes the response body, falling back to latin-1 for non-UTF-8.
  static String _decodeBody(http.Response response) {
    try {
      return utf8.decode(response.bodyBytes);
    } catch (_) {
      return response.body;
    }
  }
}
