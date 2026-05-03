/// A single key-value condition used in the object filter search.
class SearchFilter {
  final String key;
  final FilterOperator operator;
  final String value;
  final ValueType valueType;

  /// When `true`, string comparisons are case-sensitive.
  /// Only relevant for [ValueType.string] and [ValueType.any].
  final bool caseSensitive;

  const SearchFilter({
    required this.key,
    required this.operator,
    required this.value,
    this.valueType = ValueType.any,
    this.caseSensitive = false,
  });

  @override
  bool operator ==(Object other) =>
      other is SearchFilter &&
      other.key == key &&
      other.operator == operator &&
      other.value == value &&
      other.valueType == valueType &&
      other.caseSensitive == caseSensitive;

  @override
  int get hashCode =>
      Object.hash(key, operator, value, valueType, caseSensitive);

  @override
  String toString() {
    final cs = caseSensitive ? ' [Aa]' : '';
    return 'SearchFilter($key ${operator.label} "$value" ${valueType.label}$cs)';
  }
}

// ---------------------------------------------------------------------------
// ValueType
// ---------------------------------------------------------------------------

/// The expected data type of the JSON value being filtered.
///
/// Selecting a specific type makes matching strict — only nodes whose actual
/// runtime type matches will be considered. [any] preserves the original loose
/// behaviour (toString comparison, type-agnostic).
enum ValueType {
  any('Any', null),
  string('Str', 'string'),
  number('Num', 'number'),
  boolean('Bool', 'boolean'),
  nullValue('Null', 'null');

  const ValueType(this.label, this.typeName);

  /// Short label shown on filter chips and the type selector.
  final String label;

  /// Internal type name used for display; `null` for [any].
  final String? typeName;

  /// Returns the operators that make sense for this [ValueType].
  List<FilterOperator> get availableOperators => switch (this) {
        ValueType.number => const [
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

  /// Short display label shown on filter chips and the operator selector.
  final String label;
}
