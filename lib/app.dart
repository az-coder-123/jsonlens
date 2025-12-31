import 'package:flutter/material.dart';

import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'features/json_analyzer/screens/json_analyzer_screen.dart';

/// The root application widget for JSONLens.
///
/// Configures the app-wide theme and routing.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const JsonAnalyzerScreen(),
    );
  }
}
