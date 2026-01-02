import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jsonlens/core/constants/performance_constants.dart';
import 'package:jsonlens/features/json_analyzer/models/json_result.dart';
import 'package:jsonlens/features/json_analyzer/providers/json_analyzer_provider.dart';
import 'package:jsonlens/features/json_analyzer/widgets/json_output_area.dart';

class FakeNotifier extends StateNotifier<JsonAnalyzerState> {
  FakeNotifier(JsonAnalyzerState state) : super(state);
}

void main() {
  testWidgets('Large output uses virtualization ListView', (tester) async {
    // Build large output dominated by many lines
    final lines = List.generate(5000, (i) => 'line $i');
    final output = lines.join('\n');
    final state = JsonAnalyzerState(
      input: output,
      output: output,
      validationResult: const JsonValidationResult(isValid: true),
      inputSize: PerformanceConstants.plainTextVirtualizationThreshold + 100,
      isOnDemandOutput: false,
      disableSyntaxHighlighting: true,
    );

    final realNotifier = JsonAnalyzerNotifier();
    realNotifier.state = state;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [jsonAnalyzerProvider.overrideWith((ref) => realNotifier)],
        child: const MaterialApp(home: Scaffold(body: JsonOutputArea())),
      ),
    );

    // Allow frame
    await tester.pumpAndSettle();

    // Expect a ListView used for virtualization
    expect(find.byType(ListView), findsOneWidget);

    // Expect first lines are visible
    expect(find.text('line 0'), findsWidgets);
    expect(find.text('line 1'), findsWidgets);
  });
}
