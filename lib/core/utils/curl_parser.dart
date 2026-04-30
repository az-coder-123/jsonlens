import 'dart:convert';

/// Parsed result from a cURL command string.
class CurlCommand {
  /// HTTP method (defaults to `GET`, or `POST` when `--data` is present).
  final String method;

  /// The request URL.
  final String url;

  /// Request headers extracted from `-H` / `--header` flags.
  final Map<String, String> headers;

  /// Request body extracted from `-d` / `--data` / `--data-raw` /
  /// `--data-binary` / `--data-ascii` flags.
  final String body;

  const CurlCommand({
    required this.method,
    required this.url,
    required this.headers,
    required this.body,
  });
}

/// Parses a cURL command string into a [CurlCommand].
///
/// Supports the most common curl flags used in API workflows:
/// - `-X` / `--request` — HTTP method
/// - `-H` / `--header` — request headers (may appear multiple times)
/// - `-d` / `--data` / `--data-raw` / `--data-binary` / `--data-ascii` — body
/// - `-u` / `--user` — basic auth (converted to Authorization header)
/// - `-L` / `--location`, `-s`, `-v`, `--compressed`, `--insecure` — ignored
/// - Bare URL argument (with or without quotes)
///
/// Throws [FormatException] if the input is not a recognisable cURL command.
class CurlParser {
  /// Parses [input] and returns a [CurlCommand].
  static CurlCommand parse(String input) {
    final tokens = _tokenize(input.trim());
    if (tokens.isEmpty) {
      throw const FormatException('Empty input.');
    }

    // The first token must be "curl" (case-insensitive).
    if (tokens.first.toLowerCase() != 'curl') {
      throw const FormatException('Input must start with "curl".');
    }

    String? method;
    String? url;
    final headers = <String, String>{};
    String body = '';

    int i = 1;
    while (i < tokens.length) {
      final token = tokens[i];

      switch (token) {
        // ── Method ──────────────────────────────────────────────────────────
        case '-X' || '--request':
          i++;
          if (i < tokens.length) method = tokens[i].toUpperCase();

        // ── Headers ─────────────────────────────────────────────────────────
        case '-H' || '--header':
          i++;
          if (i < tokens.length) {
            final colon = tokens[i].indexOf(':');
            if (colon > 0) {
              final name = tokens[i].substring(0, colon).trim();
              final value = tokens[i].substring(colon + 1).trim();
              headers[name] = value;
            }
          }

        // ── Body ─────────────────────────────────────────────────────────────
        case '-d' ||
            '--data' ||
            '--data-raw' ||
            '--data-binary' ||
            '--data-ascii':
          i++;
          if (i < tokens.length) body = tokens[i];

        // ── Basic auth → Authorization header ────────────────────────────────
        case '-u' || '--user':
          i++;
          if (i < tokens.length) {
            final encoded = base64Encode(utf8.encode(tokens[i]));
            headers['Authorization'] = 'Basic $encoded';
          }

        // ── Ignored flags ────────────────────────────────────────────────────
        case '-L' ||
            '--location' ||
            '-s' ||
            '--silent' ||
            '-v' ||
            '--verbose' ||
            '--compressed' ||
            '-k' ||
            '--insecure' ||
            '-g' ||
            '--globoff':
          break; // consume, do nothing

        // ── Flags with values that we skip ───────────────────────────────────
        case '--connect-timeout' ||
            '--max-time' ||
            '-m' ||
            '-o' ||
            '--output' ||
            '--cert' ||
            '--key' ||
            '--cacert' ||
            '-A' ||
            '--user-agent' ||
            '--proxy' ||
            '-x':
          i++; // skip flag + its value

        // ── Bare URL or unknown token ─────────────────────────────────────────
        default:
          if (!token.startsWith('-') && url == null) {
            url = token;
          }
        // Unknown flags are silently ignored.
      }

      i++;
    }

    if (url == null || url.isEmpty) {
      throw const FormatException('No URL found in cURL command.');
    }

    // Infer method: POST when body is present and method not set.
    method ??= body.isNotEmpty ? 'POST' : 'GET';

    return CurlCommand(method: method, url: url, headers: headers, body: body);
  }

  // ---------------------------------------------------------------------------
  // Tokenizer — handles single/double-quoted strings and backslash continuations
  // ---------------------------------------------------------------------------

  static List<String> _tokenize(String input) {
    // Normalise line continuations: "...\\\n..." → "... ..."
    final normalised = input.replaceAll(RegExp(r'\\\s*\n\s*'), ' ');

    final tokens = <String>[];
    var i = 0;
    final buf = StringBuffer();

    while (i < normalised.length) {
      final ch = normalised[i];

      if (ch == ' ' || ch == '\t') {
        if (buf.isNotEmpty) {
          tokens.add(buf.toString());
          buf.clear();
        }
        i++;
      } else if (ch == "'" || ch == '"') {
        // Quoted string — consume until the matching closing quote.
        final quote = ch;
        i++;
        while (i < normalised.length && normalised[i] != quote) {
          if (normalised[i] == '\\' && i + 1 < normalised.length) {
            // Handle backslash escapes inside double-quoted strings.
            if (quote == '"') {
              i++;
              buf.write(normalised[i]);
            } else {
              // Inside single quotes, backslash is literal.
              buf.write(normalised[i]);
            }
          } else {
            buf.write(normalised[i]);
          }
          i++;
        }
        i++; // skip closing quote
        // Don't flush yet — the quoted string may be adjacent to other chars.
      } else {
        buf.write(ch);
        i++;
      }
    }

    if (buf.isNotEmpty) tokens.add(buf.toString());
    return tokens;
  }
}
