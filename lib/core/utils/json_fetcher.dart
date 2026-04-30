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

  const JsonFetchResult._({
    required this.status,
    this.statusCode,
    this.body = '',
    this.data,
    this.error,
  });

  bool get isOk => status == FetchStatus.ok;
}

/// Fetches JSON from an HTTP endpoint.
///
/// Supports GET and POST with custom headers. Times out after [timeout].
class JsonFetcher {
  static const Duration _defaultTimeout = Duration(seconds: 15);

  /// Fetches [url] using [method] (GET or POST) with optional [headers] and
  /// [body] (POST only). Parses and validates the response as JSON.
  static Future<JsonFetchResult> fetch({
    required String url,
    String method = 'GET',
    Map<String, String> headers = const {},
    String body = '',
    Duration timeout = _defaultTimeout,
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

    try {
      final http.Response response;

      if (method.toUpperCase() == 'POST') {
        response = await http
            .post(uri, headers: effectiveHeaders, body: body)
            .timeout(timeout);
      } else {
        response = await http
            .get(uri, headers: effectiveHeaders)
            .timeout(timeout);
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return JsonFetchResult._(
          status: FetchStatus.httpError,
          statusCode: response.statusCode,
          body: response.body,
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
          error: 'Response is not valid JSON: ${e.message}',
        );
      }

      return JsonFetchResult._(
        status: FetchStatus.ok,
        statusCode: response.statusCode,
        body: responseBody,
        data: parsed,
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
