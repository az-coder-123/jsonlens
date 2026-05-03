/// A single key-value condition used in the object filter search.
class SearchFilter {
  final String key;
  final FilterOperator operator;
  final String value;
  final ValueType valueType;

  /// When `true`, string comparisons are case-sensitive.
  /// Only relevant for [ValueType.string] and [ValueType.any].
  final bool caseSensitive;

  /// Format used to parse datetime strings.
  /// Only relevant when [valueType] is [ValueType.datetime].
  final DateTimeFormat dateTimeFormat;

  /// Custom `intl` DateFormat pattern (e.g. `dd/MM/yyyy HH:mm`).
  /// Only used when [dateTimeFormat] is [DateTimeFormat.custom].
  final String customDatePattern;

  /// When `false` this condition is skipped during matching but kept in the list.
  final bool enabled;

  const SearchFilter({
    required this.key,
    required this.operator,
    required this.value,
    this.valueType = ValueType.any,
    this.caseSensitive = false,
    this.dateTimeFormat = DateTimeFormat.iso8601,
    this.customDatePattern = '',
    this.enabled = true,
  });

  /// Returns a copy with [enabled] toggled.
  SearchFilter toggleEnabled() => SearchFilter(
        key: key,
        operator: operator,
        value: value,
        valueType: valueType,
        caseSensitive: caseSensitive,
        dateTimeFormat: dateTimeFormat,
        customDatePattern: customDatePattern,
        enabled: !enabled,
      );

  @override
  bool operator ==(Object other) =>
      other is SearchFilter &&
      other.key == key &&
      other.operator == operator &&
      other.value == value &&
      other.valueType == valueType &&
      other.caseSensitive == caseSensitive &&
      other.dateTimeFormat == dateTimeFormat &&
      other.customDatePattern == customDatePattern &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(
      key, operator, value, valueType, caseSensitive, dateTimeFormat,
      customDatePattern, enabled);

  @override
  String toString() {
    final cs = caseSensitive ? ' [Aa]' : '';
    final dt = valueType == ValueType.datetime
        ? dateTimeFormat == DateTimeFormat.custom
            ? ' [$customDatePattern]'
            : ' [${dateTimeFormat.label}]'
        : '';
    return 'SearchFilter($key ${operator.label} "$value" ${valueType.label}$cs$dt)';
  }
}

// ---------------------------------------------------------------------------
// ValueType
// ---------------------------------------------------------------------------

/// The expected data type of the JSON value being filtered.
enum ValueType {
  any('Any', null),
  string('Str', 'string'),
  number('Num', 'number'),
  boolean('Bool', 'boolean'),
  nullValue('Null', 'null'),
  datetime('Date', 'datetime');

  const ValueType(this.label, this.typeName);

  final String label;
  final String? typeName;

  List<FilterOperator> get availableOperators => switch (this) {
        ValueType.number || ValueType.datetime => const [
            FilterOperator.equals,
            FilterOperator.notEquals,
            FilterOperator.greaterThan,
            FilterOperator.lessThan,
            FilterOperator.greaterOrEqual,
            FilterOperator.lessOrEqual,
          ],
        ValueType.boolean || ValueType.nullValue => const [
            FilterOperator.equals,
            FilterOperator.notEquals,
          ],
        _ => const [
            FilterOperator.contains,
            FilterOperator.equals,
            FilterOperator.notEquals,
            FilterOperator.startsWith,
            FilterOperator.endsWith,
          ],
      };
}

// ---------------------------------------------------------------------------
// DateTimeFormat
// ---------------------------------------------------------------------------

/// Supported date/time serialisation formats for [ValueType.datetime] filters.
enum DateTimeFormat {
  iso8601(
    'ISO 8601',
    'yyyy-MM-dd or yyyy-MM-ddTHH:mm:ssZ',
    '2024-01-15',
  ),
  timestamp(
    'Unix (s)',
    'Seconds since epoch',
    '1705276800',
  ),
  timestampMs(
    'Unix (ms)',
    'Milliseconds since epoch',
    '1705276800000',
  ),
  custom(
    'Custom',
    'Enter a pattern using intl DateFormat tokens',
    'dd/MM/yyyy',
  );

  const DateTimeFormat(this.label, this.description, this.example);

  /// Short label shown on the format selector chips.
  final String label;

  /// Human-readable description of the format.
  final String description;

  /// Example value shown as hint in the value input field.
  final String example;
}

// ---------------------------------------------------------------------------
// FilterOperator
// ---------------------------------------------------------------------------

/// Comparison operators available in the object filter.
enum FilterOperator {
  contains('contains'),
  equals('='),
  notEquals('≠'),
  startsWith('starts'),
  endsWith('ends'),
  greaterThan('>'),
  lessThan('<'),
  greaterOrEqual('≥'),
  lessOrEqual('≤');

  const FilterOperator(this.label);
  final String label;
}
