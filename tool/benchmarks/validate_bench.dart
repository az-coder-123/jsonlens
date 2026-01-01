// ignore_for_file: avoid_print

import 'package:jsonlens/core/utils/json_validator.dart';

Future<void> main() async {
  final valid = '{"a":1, "b": [1,2,3]}';
  final invalid = '{"a":1, "b": [1,2,}';

  final r1 = await JsonValidator.validateAsync(valid);
  print(
    'valid result: isValid=${r1.isValid}, line=${r1.lineNumber}, msg=${r1.errorMessage}',
  );

  final r2 = await JsonValidator.validateAsync(invalid);
  print(
    'invalid result: isValid=${r2.isValid}, line=${r2.lineNumber}, msg=${r2.errorMessage}, offset=${r2.errorOffset}',
  );
}
