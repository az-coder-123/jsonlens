# AGENTS.md - AI Agent Guidelines for JSONLens Project

## 📋 Project Overview

**JSONLens** is a professional-grade JSON Analyzer & Formatter Flutter application for mobile and desktop platforms (iOS, macOS, Windows, Android, Linux).

---

## 🎯 Core Requirements

### 1. Logic & Validation
- Implement real-time JSON parsing and validation
- Use `dart:convert` for formatting with **2-space indent**
- Catch parsing errors and display descriptive error messages (line number/reason)

### 2. User Interface (UI)
- **Theme**: Professional Dark Mode by default
- **Font**: Use `JetBrains Mono` from `google_fonts` for all JSON displays
- **Layout**: Split-screen or toggle-view layout
  - Top/Left: Input area (TextField with syntax highlighting support)
  - Bottom/Right: Output area (Syntax highlighted JSON and Tree View)

### 3. Key Features
- **Syntax Highlighting**: Use `flutter_highlight` package for formatted JSON output
- **Tree View**: Integrate `flutter_json_view` for expand/collapse JSON nodes
- **Toolbar**: Buttons for "Format", "Minify", "Clear", "Copy to Clipboard", "Paste from Clipboard"
- **Validation Indicator**: Status bar showing "Valid" (Green) or "Invalid" (Red)

### 4. Technical Stack
- **Packages**: `flutter_highlight`, `google_fonts`, `flutter_json_view`, `flutter/services`
- **State Management**: `Riverpod` (flutter_riverpod)
- **Code Quality**: Modular, well-commented, follows Flutter best practices

---

## 🏗️ Project Structure

```
lib/
├── main.dart                    # App entry point
├── app.dart                     # App widget configuration
├── core/
│   ├── constants/
│   │   ├── app_colors.dart      # Color constants
│   │   ├── app_strings.dart     # String constants
│   │   └── app_dimensions.dart  # Dimension constants
│   ├── theme/
│   │   └── app_theme.dart       # Theme configuration
│   └── utils/
│       ├── json_formatter.dart  # JSON formatting utilities
│       ├── json_validator.dart  # JSON validation utilities
│       └── clipboard_helper.dart # Clipboard operations
├── features/
│   └── json_analyzer/
│       ├── models/
│       │   └── json_result.dart # JSON parsing result model
│       ├── providers/
│       │   └── json_analyzer_provider.dart # Riverpod state management
│       ├── widgets/
│       │   ├── json_input_area.dart    # Input text field
│       │   ├── json_output_area.dart   # Output display
│       │   ├── json_tree_view.dart     # Tree view widget
│       │   ├── toolbar.dart            # Action toolbar
│       │   └── validation_indicator.dart # Status bar
│       └── screens/
│           └── json_analyzer_screen.dart # Main screen
└── shared/
    └── widgets/
        └── ...                  # Shared widgets
```

---

## 📐 Coding Principles

### 1. Clean Code

#### Naming Conventions
```dart
// ✅ Good - Descriptive and meaningful names
class JsonValidationResult { }
void formatJsonWithIndent(String input, int indent) { }
final bool isValidJson;

// ❌ Bad - Vague or abbreviated names
class JVR { }
void fmt(String i, int n) { }
final bool valid;
```

#### Function Length
- Keep functions **under 30 lines**
- Each function should do **one thing only**
- Extract complex logic into separate helper functions

```dart
// ✅ Good - Single responsibility
String formatJson(String input) {
  final decoded = _decodeJson(input);
  return _encodeWithIndent(decoded);
}

dynamic _decodeJson(String input) => jsonDecode(input);
String _encodeWithIndent(dynamic data) => JsonEncoder.withIndent('  ').convert(data);

// ❌ Bad - Multiple responsibilities in one function
String processJson(String input) {
  // 50+ lines doing validation, formatting, error handling...
}
```

#### Comments
- Write **self-documenting code** first
- Use comments to explain **WHY**, not **WHAT**
- Use `///` for documentation comments on public APIs

```dart
/// Formats JSON string with 2-space indentation.
/// 
/// Throws [FormatException] if [input] is not valid JSON.
String formatJson(String input) { }
```

#### Language Policy
- **English is the required language for all project communication and artifacts.** This includes:
  - Code comments and documentation (in `lib/`, `README.md`, `AGENTS.md`, `docs/`, etc.)
  - Logs and runtime diagnostic messages
  - Commit messages, pull request titles/descriptions, and issue titles/comments
  - CI job names, pipeline logs, and release notes
- Rationale: using English ensures consistency, improves accessibility for international contributors, and enables better tooling/automation.
- Exceptions: when using a non-English phrase is necessary (e.g., reproducing a user-reported string), include a short English translation immediately adjacent.
- Enforcement: reviewers should request changes for non-English content during code review; consider adding automated checks (linters or CI scripts) to flag non-English text in documentation and comments where practical.

### 2. Avoid Duplication (DRY Principle)

#### Extract Common Logic
```dart
// ✅ Good - Reusable utility
class JsonFormatter {
  static const _indent = '  ';
  static final _encoder = JsonEncoder.withIndent(_indent);
  
  static String format(dynamic data) => _encoder.convert(data);
}

// ❌ Bad - Duplicated across files
// In file1.dart
final formatted = JsonEncoder.withIndent('  ').convert(data);
// In file2.dart
final formatted = JsonEncoder.withIndent('  ').convert(data);
```

#### Extract Common Widgets
```dart
// ✅ Good - Reusable widget
class ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  
  const ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  
  @override
  Widget build(BuildContext context) { }
}

// Usage
ActionButton(label: 'Format', icon: Icons.format_align_left, onPressed: _format)
ActionButton(label: 'Minify', icon: Icons.compress, onPressed: _minify)
```

### 3. Single Responsibility Principle (SRP)

#### File Level
- Each file should contain **one class/concept**
- File name should match the class name (snake_case)

```
✅ Good:
json_formatter.dart      → class JsonFormatter
json_validator.dart      → class JsonValidator
clipboard_helper.dart    → class ClipboardHelper

❌ Bad:
utils.dart → contains JsonFormatter, JsonValidator, ClipboardHelper
```

#### Class Level
```dart
// ✅ Good - Single responsibility per class
class JsonValidator {
  ValidationResult validate(String input) { }
}

class JsonFormatter {
  String format(String input) { }
  String minify(String input) { }
}

// ❌ Bad - Multiple responsibilities
class JsonHelper {
  ValidationResult validate(String input) { }
  String format(String input) { }
  void copyToClipboard(String text) { }
  void showSnackbar(String message) { }
}
```

#### Method Level
```dart
// ✅ Good - Each method does one thing
void _handleFormatPressed() {
  final result = _validator.validate(_inputController.text);
  if (result.isValid) {
    _updateOutput(_formatter.format(_inputController.text));
  } else {
    _showError(result.errorMessage);
  }
}

// ❌ Bad - Method doing too many things
void _handleFormatPressed() {
  try {
    final decoded = jsonDecode(_inputController.text);
    final formatted = JsonEncoder.withIndent('  ').convert(decoded);
    setState(() {
      _output = formatted;
      _isValid = true;
      _errorMessage = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(...);
  } catch (e) {
    // error handling...
  }
}
```

---

## 🎨 Flutter Best Practices

### 1. Widget Building

#### Use `const` Constructors
```dart
// ✅ Good
const SizedBox(height: 16)
const EdgeInsets.all(16)
const Text('Hello')

// ❌ Bad
SizedBox(height: 16)
EdgeInsets.all(16)
Text('Hello')
```

#### Prefer `const` Widgets
```dart
// ✅ Good
class MyWidget extends StatelessWidget {
  const MyWidget({super.key});
  
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Text('Hello'),
    );
  }
}
```

#### Extract Widgets, Not Methods
```dart
// ✅ Good - Separate widget class
class JsonInputArea extends StatelessWidget {
  const JsonInputArea({super.key});
  
  @override
  Widget build(BuildContext context) { }
}

// ❌ Bad - Build method returning widget
Widget _buildInputArea() {
  return Container(...);
}
```

### 2. State Management with Riverpod

#### Define State Class
```dart
@immutable
class JsonAnalyzerState {
  final String input;
  final String output;
  final bool isValid;
  final String errorMessage;
  
  const JsonAnalyzerState({
    this.input = '',
    this.output = '',
    this.isValid = false,
    this.errorMessage = '',
  });
  
  JsonAnalyzerState copyWith({
    String? input,
    String? output,
    bool? isValid,
    String? errorMessage,
  }) {
    return JsonAnalyzerState(
      input: input ?? this.input,
      output: output ?? this.output,
      isValid: isValid ?? this.isValid,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
```

#### Create Notifier
```dart
class JsonAnalyzerNotifier extends StateNotifier<JsonAnalyzerState> {
  JsonAnalyzerNotifier() : super(const JsonAnalyzerState());
  
  void updateInput(String value) {
    state = state.copyWith(input: value);
    _validateAndFormat();
  }
}

// Define provider
final jsonAnalyzerProvider = 
    StateNotifierProvider<JsonAnalyzerNotifier, JsonAnalyzerState>(
  (ref) => JsonAnalyzerNotifier(),
);
```

#### Consume State in Widgets
```dart
// ✅ Good - Use ConsumerWidget
class JsonOutputArea extends ConsumerWidget {
  const JsonOutputArea({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final output = ref.watch(jsonAnalyzerProvider.select((s) => s.output));
    return Text(output);
  }
}

// ✅ Good - Use ref.watch with select for specific properties
final isValid = ref.watch(jsonAnalyzerProvider.select((s) => s.isValid));

// ✅ Good - Use ref.read for actions (don't rebuild on change)
ref.read(jsonAnalyzerProvider.notifier).updateInput(value);
```

### 3. Avoid Deprecated APIs

#### Use New Button Widgets
```dart
// ✅ Good
ElevatedButton(onPressed: () {}, child: Text('Click'))
TextButton(onPressed: () {}, child: Text('Click'))
OutlinedButton(onPressed: () {}, child: Text('Click'))

// ❌ Bad (Deprecated)
RaisedButton(onPressed: () {}, child: Text('Click'))
FlatButton(onPressed: () {}, child: Text('Click'))
```

#### Use `super.key` in Constructors
```dart
// ✅ Good (Dart 2.17+)
const MyWidget({super.key});

// ❌ Outdated
const MyWidget({Key? key}) : super(key: key);
```

#### Use `context.mounted` Check
```dart
// ✅ Good
Future<void> _loadData() async {
  await Future.delayed(Duration(seconds: 1));
  if (!mounted) return; // For StatefulWidget
  // or
  if (!context.mounted) return; // For async gaps
  setState(() { });
}
```

### 4. Performance

#### Use `ListView.builder` for Long Lists
```dart
// ✅ Good
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(item: items[index]),
)

// ❌ Bad
ListView(
  children: items.map((item) => ItemWidget(item: item)).toList(),
)
```

#### Cache Expensive Computations
```dart
// ✅ Good
late final _jsonEncoder = JsonEncoder.withIndent('  ');

String format(dynamic data) => _jsonEncoder.convert(data);
```

---

## 📦 Package Usage Guidelines

### flutter_highlight
```dart
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';

HighlightView(
  formattedJson,
  language: 'json',
  theme: atomOneDarkTheme,
  textStyle: GoogleFonts.jetBrainsMono(fontSize: 14),
)
```

### google_fonts
```dart
import 'package:google_fonts/google_fonts.dart';

// For text style
GoogleFonts.jetBrainsMono(
  fontSize: 14,
  color: Colors.white,
)

// For theme
theme: ThemeData(
  textTheme: GoogleFonts.jetBrainsMonoTextTheme(),
)
```

### flutter_json_view
```dart
import 'package:flutter_json_view/flutter_json_view.dart';

JsonView.map(
  jsonData, // Map<String, dynamic>
  theme: JsonViewTheme(
    // customize colors
  ),
)
```

### Clipboard
```dart
import 'package:flutter/services.dart';

// Copy
await Clipboard.setData(ClipboardData(text: content));

// Paste
final data = await Clipboard.getData(Clipboard.kTextPlain);
final text = data?.text ?? '';
```

---

## ✅ Code Review Checklist

Before submitting code, ensure:

- [ ] No duplicate code exists
- [ ] Each file contains only one class/concept
- [ ] Each class has a single responsibility
- [ ] Each method is under 30 lines
- [ ] All widgets use `const` where possible
- [ ] No deprecated APIs are used
- [ ] All public APIs have documentation comments
- [ ] State management follows the chosen pattern consistently
- [ ] Error handling is implemented properly
- [ ] Code follows naming conventions

---

## 🚫 Anti-Patterns to Avoid

1. **God Classes**: Classes that do everything
2. **Long Methods**: Methods over 30 lines
3. **Magic Numbers**: Use named constants instead
4. **Deep Nesting**: Max 3 levels of nesting
5. **Callback Hell**: Extract to named functions
6. **setState() Abuse**: Use proper state management
7. **BuildContext Across Async Gaps**: Check `mounted` first

---

## 📝 Git Commit Convention

```
feat: add JSON formatting feature
fix: resolve parsing error for nested arrays
refactor: extract validation logic to separate class
style: format code according to dart standards
docs: update AGENTS.md with new guidelines
test: add unit tests for JsonFormatter
chore: update dependencies
```

---

## 🔧 Development Commands

```bash
# Get dependencies
flutter pub get

# Run the app
flutter run

# Run on specific platform
flutter run -d macos
flutter run -d windows
flutter run -d linux
flutter run -d chrome

# Analyze code
flutter analyze

# Format code
dart format lib/

# Run tests
flutter test
```
