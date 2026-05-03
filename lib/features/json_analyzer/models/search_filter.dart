/// A single key-value condition used in the object filter search.
class SearchFilter {
  final String key;
  final FilterOperator operator;
  final String value;

  const SearchFilter({
    required this.key,
    required this.operator,
    required this.value,
  });

  @override
  bool operator ==(Object other) =>
      other is SearchFilter &&
      other.key == key &&
      other.operator == operator &&
      other.value == value;

  @override
  int get hashCode => Object.hash(key, operator, value);

  @override
  String toString() => 'SearchFilter($key ${operator.label} "$value")';
}

/// Comparison operators available in the object filter.
enum FilterOperator {
  contains('contains'),
  equals('='),
  notEquals('≠'),
  startsWith('starts'),
  endsWith('ends');

  const FilterOperator(this.label);

  /// Short display label shown on filter chips and the operator selector.
  final String label;
}
