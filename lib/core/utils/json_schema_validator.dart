import 'dart:convert';

/// A single validation error produced by [JsonSchemaValidator].
class SchemaValidationError {
  /// JSON pointer path to the failing value (e.g. `$.users[0].email`).
  final String path;

  /// The schema keyword that failed (e.g. `type`, `required`, `minLength`).
  final String constraint;

  /// Human-readable description of the failure.
  final String message;

  const SchemaValidationError({
    required this.path,
    required this.constraint,
    required this.message,
  });

  @override
  String toString() => '[$constraint] $path — $message';
}

/// Result returned by [JsonSchemaValidator.validate].
class SchemaValidationResult {
  final bool isValid;
  final List<SchemaValidationError> errors;

  /// Set when the schema itself cannot be parsed.
  final String? schemaParseError;

  const SchemaValidationResult({
    required this.isValid,
    this.errors = const [],
    this.schemaParseError,
  });
}

/// Validates a JSON document against a JSON Schema (draft-7 subset).
///
/// Supported keywords: `type`, `properties`, `required`,
/// `additionalProperties`, `patternProperties`, `minProperties`,
/// `maxProperties`, `items`, `additionalItems`, `contains`, `minItems`,
/// `maxItems`, `uniqueItems`, `minimum`, `maximum`, `exclusiveMinimum`,
/// `exclusiveMaximum`, `multipleOf`, `minLength`, `maxLength`, `pattern`,
/// `format` (date-time, date, email, uri, ipv4), `enum`, `const`,
/// `allOf`, `anyOf`, `oneOf`, `not`, `$ref` (local #/… only),
/// `definitions` / `$defs`.
class JsonSchemaValidator {
  final Map<String, dynamic> _rootSchema;
  final List<SchemaValidationError> _errors = [];

  JsonSchemaValidator._(this._rootSchema);

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Parses [schemaText] and [jsonText], then validates the document.
  ///
  /// Returns a [SchemaValidationResult] containing all errors found.
  static SchemaValidationResult validate(String schemaText, String jsonText) {
    // Parse schema.
    dynamic rawSchema;
    try {
      rawSchema = jsonDecode(schemaText);
    } catch (e) {
      return SchemaValidationResult(
        isValid: false,
        schemaParseError: 'Invalid schema JSON: $e',
      );
    }
    if (rawSchema is! Map<String, dynamic>) {
      return const SchemaValidationResult(
        isValid: false,
        schemaParseError: 'Schema must be a JSON object.',
      );
    }

    // Parse document.
    dynamic document;
    try {
      document = jsonDecode(jsonText);
    } catch (e) {
      return SchemaValidationResult(
        isValid: false,
        errors: [
          SchemaValidationError(
            path: r'$',
            constraint: 'parse',
            message: 'Document is not valid JSON: $e',
          ),
        ],
      );
    }

    final validator = JsonSchemaValidator._(rawSchema);
    validator._validate(rawSchema, document, r'$');
    return SchemaValidationResult(
      isValid: validator._errors.isEmpty,
      errors: List.unmodifiable(validator._errors),
    );
  }

  // ---------------------------------------------------------------------------
  // Core dispatch
  // ---------------------------------------------------------------------------

  void _validate(Map<String, dynamic> schema, dynamic value, String path) {
    // Resolve $ref and stop — combined keywords alongside $ref are draft-2019+.
    if (schema.containsKey(r'$ref')) {
      final resolved = _resolveRef(schema[r'$ref'] as String);
      if (resolved != null) _validate(resolved, value, path);
      return;
    }

    // An empty schema `{}` is always valid.
    if (schema.isEmpty) return;

    _checkType(schema, value, path);
    _checkEnum(schema, value, path);
    _checkConst(schema, value, path);
    _checkAllOf(schema, value, path);
    _checkAnyOf(schema, value, path);
    _checkOneOf(schema, value, path);
    _checkNot(schema, value, path);

    if (value is String) _checkStringConstraints(schema, value, path);
    if (value is num) _checkNumericConstraints(schema, value, path);
    if (value is Map<String, dynamic>)
      _checkObjectConstraints(schema, value, path);
    if (value is List) _checkArrayConstraints(schema, value, path);
  }

  // ---------------------------------------------------------------------------
  // type
  // ---------------------------------------------------------------------------

  void _checkType(Map<String, dynamic> schema, dynamic value, String path) {
    final typeSpec = schema['type'];
    if (typeSpec == null) return;

    final types = typeSpec is List
        ? List<String>.from(typeSpec)
        : [typeSpec as String];

    if (types.any((t) => _matchesType(t, value))) return;

    _addError(path, 'type', 'Expected type $typeSpec, got ${_typeName(value)}');
  }

  bool _matchesType(String type, dynamic value) => switch (type) {
    'null' => value == null,
    'boolean' => value is bool,
    'integer' =>
      value is int || (value is double && value == value.truncateToDouble()),
    'number' => value is num,
    'string' => value is String,
    'array' => value is List,
    'object' => value is Map,
    _ => false,
  };

  String _typeName(dynamic value) {
    if (value == null) return 'null';
    if (value is bool) return 'boolean';
    if (value is int) return 'integer';
    if (value is double) return 'number';
    if (value is String) return 'string';
    if (value is List) return 'array';
    if (value is Map) return 'object';
    return 'unknown';
  }

  // ---------------------------------------------------------------------------
  // enum / const
  // ---------------------------------------------------------------------------

  void _checkEnum(Map<String, dynamic> schema, dynamic value, String path) {
    final allowed = schema['enum'];
    if (allowed is! List) return;
    if (!allowed.any((e) => _deepEquals(e, value))) {
      _addError(
        path,
        'enum',
        'Value must be one of: ${allowed.map(jsonEncode).join(', ')}',
      );
    }
  }

  void _checkConst(Map<String, dynamic> schema, dynamic value, String path) {
    if (!schema.containsKey('const')) return;
    if (!_deepEquals(schema['const'], value)) {
      _addError(
        path,
        'const',
        'Value must equal ${jsonEncode(schema['const'])}',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Combiners
  // ---------------------------------------------------------------------------

  void _checkAllOf(Map<String, dynamic> schema, dynamic value, String path) {
    final allOf = schema['allOf'];
    if (allOf is! List) return;
    for (final sub in allOf) {
      if (sub is Map<String, dynamic>) _validate(sub, value, path);
    }
  }

  void _checkAnyOf(Map<String, dynamic> schema, dynamic value, String path) {
    final anyOf = schema['anyOf'];
    if (anyOf is! List) return;
    for (final sub in anyOf) {
      if (sub is Map<String, dynamic>) {
        final child = JsonSchemaValidator._(_rootSchema);
        child._validate(sub, value, path);
        if (child._errors.isEmpty) return;
      }
    }
    _addError(
      path,
      'anyOf',
      'Value does not match any of the required schemas',
    );
  }

  void _checkOneOf(Map<String, dynamic> schema, dynamic value, String path) {
    final oneOf = schema['oneOf'];
    if (oneOf is! List) return;
    var matchCount = 0;
    for (final sub in oneOf) {
      if (sub is Map<String, dynamic>) {
        final child = JsonSchemaValidator._(_rootSchema);
        child._validate(sub, value, path);
        if (child._errors.isEmpty) matchCount++;
      }
    }
    if (matchCount != 1) {
      _addError(
        path,
        'oneOf',
        'Value must match exactly one schema (matched $matchCount)',
      );
    }
  }

  void _checkNot(Map<String, dynamic> schema, dynamic value, String path) {
    final not = schema['not'];
    if (not is! Map<String, dynamic>) return;
    final child = JsonSchemaValidator._(_rootSchema);
    child._validate(not, value, path);
    if (child._errors.isEmpty) {
      _addError(path, 'not', 'Value must NOT match the negated schema');
    }
  }

  // ---------------------------------------------------------------------------
  // String constraints
  // ---------------------------------------------------------------------------

  void _checkStringConstraints(
    Map<String, dynamic> schema,
    String value,
    String path,
  ) {
    final minLength = schema['minLength'];
    if (minLength is int && value.length < minLength) {
      _addError(
        path,
        'minLength',
        'String length ${value.length} is less than minimum $minLength',
      );
    }

    final maxLength = schema['maxLength'];
    if (maxLength is int && value.length > maxLength) {
      _addError(
        path,
        'maxLength',
        'String length ${value.length} exceeds maximum $maxLength',
      );
    }

    final pattern = schema['pattern'];
    if (pattern is String) {
      try {
        if (!RegExp(pattern).hasMatch(value)) {
          _addError(
            path,
            'pattern',
            'String does not match pattern "$pattern"',
          );
        }
      } catch (_) {
        _addError(path, 'pattern', 'Invalid regex pattern "$pattern"');
      }
    }

    final format = schema['format'];
    if (format is String) _checkFormat(format, value, path);
  }

  void _checkFormat(String format, String value, String path) {
    switch (format) {
      case 'date-time':
        if (DateTime.tryParse(value) == null) {
          _addError(
            path,
            'format:date-time',
            '"$value" is not a valid date-time',
          );
        }
      case 'date':
        final re = RegExp(r'^\d{4}-\d{2}-\d{2}$');
        if (!re.hasMatch(value) || DateTime.tryParse(value) == null) {
          _addError(path, 'format:date', '"$value" is not a valid date');
        }
      case 'email':
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
          _addError(
            path,
            'format:email',
            '"$value" is not a valid email address',
          );
        }
      case 'uri':
        final parsed = Uri.tryParse(value);
        if (parsed == null || !parsed.hasScheme) {
          _addError(path, 'format:uri', '"$value" is not a valid URI');
        }
      case 'ipv4':
        if (!RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(value)) {
          _addError(
            path,
            'format:ipv4',
            '"$value" is not a valid IPv4 address',
          );
        }
    }
  }

  // ---------------------------------------------------------------------------
  // Numeric constraints
  // ---------------------------------------------------------------------------

  void _checkNumericConstraints(
    Map<String, dynamic> schema,
    num value,
    String path,
  ) {
    final minimum = schema['minimum'];
    if (minimum is num && value < minimum) {
      _addError(path, 'minimum', 'Value $value is less than minimum $minimum');
    }

    final maximum = schema['maximum'];
    if (maximum is num && value > maximum) {
      _addError(path, 'maximum', 'Value $value exceeds maximum $maximum');
    }

    // Draft-7: exclusiveMinimum / exclusiveMaximum are numbers (not booleans).
    final exMin = schema['exclusiveMinimum'];
    if (exMin is num && value <= exMin) {
      _addError(path, 'exclusiveMinimum', 'Value $value must be > $exMin');
    }

    final exMax = schema['exclusiveMaximum'];
    if (exMax is num && value >= exMax) {
      _addError(path, 'exclusiveMaximum', 'Value $value must be < $exMax');
    }

    final multipleOf = schema['multipleOf'];
    if (multipleOf is num && multipleOf > 0) {
      final remainder = value % multipleOf;
      if (remainder.abs() > 1e-10 && (multipleOf - remainder).abs() > 1e-10) {
        _addError(
          path,
          'multipleOf',
          'Value $value is not a multiple of $multipleOf',
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Object constraints
  // ---------------------------------------------------------------------------

  void _checkObjectConstraints(
    Map<String, dynamic> schema,
    Map<String, dynamic> value,
    String path,
  ) {
    // required
    final required = schema['required'];
    if (required is List) {
      for (final key in required) {
        if (key is String && !value.containsKey(key)) {
          _addError(path, 'required', 'Missing required property "$key"');
        }
      }
    }

    // minProperties / maxProperties
    final minProps = schema['minProperties'];
    if (minProps is int && value.length < minProps) {
      _addError(
        path,
        'minProperties',
        'Object has ${value.length} properties, minimum is $minProps',
      );
    }

    final maxProps = schema['maxProperties'];
    if (maxProps is int && value.length > maxProps) {
      _addError(
        path,
        'maxProperties',
        'Object has ${value.length} properties, maximum is $maxProps',
      );
    }

    // properties — validate each known key
    final properties = schema['properties'];
    if (properties is Map<String, dynamic>) {
      for (final entry in properties.entries) {
        if (value.containsKey(entry.key) &&
            entry.value is Map<String, dynamic>) {
          _validate(
            entry.value as Map<String, dynamic>,
            value[entry.key],
            '$path.${entry.key}',
          );
        }
      }
    }

    // patternProperties
    final patternProperties = schema['patternProperties'];
    final matchedByPattern = <String>{};
    if (patternProperties is Map<String, dynamic>) {
      for (final entry in patternProperties.entries) {
        try {
          final re = RegExp(entry.key);
          for (final key in value.keys) {
            if (re.hasMatch(key)) {
              matchedByPattern.add(key);
              if (entry.value is Map<String, dynamic>) {
                _validate(
                  entry.value as Map<String, dynamic>,
                  value[key],
                  '$path.$key',
                );
              }
            }
          }
        } catch (_) {}
      }
    }

    // additionalProperties
    final additionalProperties = schema['additionalProperties'];
    if (additionalProperties != null) {
      final knownKeys = <String>{};
      if (properties is Map) knownKeys.addAll(properties.keys.cast<String>());
      knownKeys.addAll(matchedByPattern);

      for (final key in value.keys) {
        if (!knownKeys.contains(key)) {
          if (additionalProperties is bool && !additionalProperties) {
            _addError(
              '$path.$key',
              'additionalProperties',
              'Additional property "$key" is not allowed',
            );
          } else if (additionalProperties is Map<String, dynamic>) {
            _validate(additionalProperties, value[key], '$path.$key');
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Array constraints
  // ---------------------------------------------------------------------------

  void _checkArrayConstraints(
    Map<String, dynamic> schema,
    List<dynamic> value,
    String path,
  ) {
    final minItems = schema['minItems'];
    if (minItems is int && value.length < minItems) {
      _addError(
        path,
        'minItems',
        'Array has ${value.length} items, minimum is $minItems',
      );
    }

    final maxItems = schema['maxItems'];
    if (maxItems is int && value.length > maxItems) {
      _addError(
        path,
        'maxItems',
        'Array has ${value.length} items, maximum is $maxItems',
      );
    }

    // uniqueItems
    final uniqueItems = schema['uniqueItems'];
    if (uniqueItems == true) {
      final seen = <String>{};
      for (var i = 0; i < value.length; i++) {
        final encoded = jsonEncode(value[i]);
        if (!seen.add(encoded)) {
          _addError('$path[$i]', 'uniqueItems', 'Duplicate item at index $i');
        }
      }
    }

    // items (schema or tuple)
    final items = schema['items'];
    if (items is Map<String, dynamic>) {
      for (var i = 0; i < value.length; i++) {
        _validate(items, value[i], '$path[$i]');
      }
    } else if (items is List) {
      // Tuple validation: each position has its own schema.
      for (var i = 0; i < items.length && i < value.length; i++) {
        if (items[i] is Map<String, dynamic>) {
          _validate(items[i] as Map<String, dynamic>, value[i], '$path[$i]');
        }
      }
      // additionalItems
      final additionalItems = schema['additionalItems'];
      if (value.length > items.length) {
        if (additionalItems is bool && !additionalItems) {
          for (var i = items.length; i < value.length; i++) {
            _addError(
              '$path[$i]',
              'additionalItems',
              'Additional item at index $i is not allowed',
            );
          }
        } else if (additionalItems is Map<String, dynamic>) {
          for (var i = items.length; i < value.length; i++) {
            _validate(additionalItems, value[i], '$path[$i]');
          }
        }
      }
    }

    // contains
    final contains = schema['contains'];
    if (contains is Map<String, dynamic>) {
      final found = value.any((item) {
        final child = JsonSchemaValidator._(_rootSchema);
        child._validate(contains, item, path);
        return child._errors.isEmpty;
      });
      if (!found) {
        _addError(
          path,
          'contains',
          'Array does not contain any item matching the "contains" schema',
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // $ref resolution (local JSON Pointer only: #/...)
  // ---------------------------------------------------------------------------

  Map<String, dynamic>? _resolveRef(String ref) {
    if (!ref.startsWith('#')) return null;
    final pointer = ref.substring(1);
    if (pointer.isEmpty) return _rootSchema;

    final parts = pointer
        .split('/')
        .where((p) => p.isNotEmpty)
        .map((p) => p.replaceAll('~1', '/').replaceAll('~0', '~'))
        .toList();

    dynamic node = _rootSchema;
    for (final part in parts) {
      if (node is Map && node.containsKey(part)) {
        node = node[part];
      } else {
        return null;
      }
    }
    return node is Map<String, dynamic> ? node : null;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _addError(String path, String constraint, String message) {
    _errors.add(
      SchemaValidationError(
        path: path,
        constraint: constraint,
        message: message,
      ),
    );
  }

  bool _deepEquals(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key)) return false;
        if (!_deepEquals(a[key], b[key])) return false;
      }
      return true;
    }
    return a == b;
  }
}
