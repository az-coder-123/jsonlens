/// Scans formatted (2-space-indented) JSON text and builds bidirectional
/// JSON-path ↔ 0-based-line-number mappings.
///
/// Works correctly with output produced by [JsonEncoder.withIndent('  ')].
/// If the source text is minified (no newlines), the mapper returns empty maps
/// and all look-ups return null.
class JsonPositionMapper {
  final Map<String, int> _pathToLine;
  final Map<int, String> _lineToPath;

  JsonPositionMapper._(this._pathToLine, this._lineToPath);

  /// Returns the 0-based line number of [path], or null if not found.
  int? lineForPath(String path) => _pathToLine[path];

  /// Returns the JSON path for the given 0-based [line], or null.
  String? pathForLine(int line) => _lineToPath[line];

  // ---------------------------------------------------------------------------
  // Factory
  // ---------------------------------------------------------------------------

  /// Builds a mapper from [formattedJson].
  ///
  /// Paths follow the `$.key[0].subkey` notation used by [LazyJsonTree].
  factory JsonPositionMapper.build(String formattedJson) {
    final pathToLine = <String, int>{};
    final lineToPath = <int, String>{};

    if (!formattedJson.contains('\n')) {
      // Minified — nothing to map.
      return JsonPositionMapper._(pathToLine, lineToPath);
    }

    final lines = formattedJson.split('\n');

    // Stack: each entry describes an open container.
    // path       = JSON path of this container (e.g. '$.users').
    // isArray    = true for JSON arrays, false for JSON objects.
    // nextIndex  = next array index to assign (only meaningful when isArray).
    final stack = <({String path, bool isArray, int nextIndex})>[];

    for (int i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final leftTrimmed = raw.trimLeft();
      if (leftTrimmed.isEmpty) continue;

      final indent = raw.length - leftTrimmed.length;
      final depth = indent ~/ 2;
      final trimmed = _stripComma(leftTrimmed);

      // Pop stack down to current depth.
      while (stack.length > depth) {
        stack.removeLast();
      }

      // Closing brackets are handled by the pop above.
      if (trimmed == '}' || trimmed == ']') continue;

      final parentPath = stack.isEmpty ? r'$' : stack.last.path;
      final parentIsArray = stack.isNotEmpty && stack.last.isArray;

      // ---- Object key → value (e.g. `"name": "Alice"`) ----
      final keyMatch = RegExp(
        r'^"((?:[^"\\]|\\.)*)":\s*(.*)',
      ).firstMatch(trimmed);
      if (keyMatch != null) {
        final key = keyMatch.group(1)!;
        final rest = _stripComma(keyMatch.group(2)!.trimRight());
        final nodePath = '$parentPath.$key';

        pathToLine[nodePath] = i;
        lineToPath[i] = nodePath;

        if (rest == '{') {
          stack.add((path: nodePath, isArray: false, nextIndex: 0));
        } else if (rest == '[') {
          stack.add((path: nodePath, isArray: true, nextIndex: 0));
        }
        continue;
      }

      // ---- Container opener (`{` or `[`) without a preceding key ----
      if (trimmed == '{' || trimmed == '[') {
        if (stack.isEmpty) {
          // Root container.
          pathToLine[r'$'] = i;
          lineToPath[i] = r'$';
          stack.add((path: r'$', isArray: trimmed == '[', nextIndex: 0));
        } else if (parentIsArray) {
          final idx = stack.last.nextIndex;
          final nodePath = '$parentPath[$idx]';

          pathToLine[nodePath] = i;
          lineToPath[i] = nodePath;

          // Increment parent array index.
          stack[stack.length - 1] = (
            path: stack.last.path,
            isArray: true,
            nextIndex: idx + 1,
          );

          // Push new container scope.
          stack.add((path: nodePath, isArray: trimmed == '[', nextIndex: 0));
        }
        continue;
      }

      // ---- Scalar array item (anything else inside an array) ----
      if (parentIsArray) {
        final idx = stack.last.nextIndex;
        final nodePath = '$parentPath[$idx]';

        pathToLine[nodePath] = i;
        lineToPath[i] = nodePath;

        stack[stack.length - 1] = (
          path: stack.last.path,
          isArray: true,
          nextIndex: idx + 1,
        );
      }
    }

    return JsonPositionMapper._(pathToLine, lineToPath);
  }

  static String _stripComma(String s) =>
      s.endsWith(',') ? s.substring(0, s.length - 1) : s;
}
