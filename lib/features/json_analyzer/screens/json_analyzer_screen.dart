import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/error_display.dart';
import '../../version_check/about_dialog.dart';
import '../../version_check/version_banner.dart';
import '../../version_check/version_notifier.dart';
import '../providers/json_analyzer_provider.dart';
import '../widgets/json_compare_panel.dart';
import '../widgets/json_input_area.dart';
import '../widgets/json_path_query_panel.dart';
import '../widgets/json_schema_panel.dart';
import '../widgets/json_statistics_panel.dart';
import '../widgets/json_tree_view.dart';
import '../widgets/validation_indicator.dart';

/// Main screen for the JSON Analyzer application.
///
/// Provides a split-view layout with input area, output area,
/// toolbar, and validation indicator.
class JsonAnalyzerScreen extends ConsumerStatefulWidget {
  const JsonAnalyzerScreen({super.key});

  @override
  ConsumerState<JsonAnalyzerScreen> createState() => _JsonAnalyzerScreenState();
}

class _JsonAnalyzerScreenState extends ConsumerState<JsonAnalyzerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _toolsTabController;
  bool _showTools = false;

  // Preserve the input area's state (TextEditingController, selection, etc.)
  // when the layout rebuilds or re-parents the widget (e.g. switching between
  // horizontal and vertical splits).
  final GlobalKey _inputKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _toolsTabController = TabController(length: 5, vsync: this);

    // Trigger a background version check (non-blocking)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Force a network version check on every cold launch (non-blocking)
      // ignore: unused_result
      ref
          .read(versionNotifierProvider.notifier)
          .checkForUpdateIfConnected(force: true);
    });
  }

  @override
  void dispose() {
    _toolsTabController.dispose();
    super.dispose();
  }

  void _toggleTools() {
    setState(() {
      _showTools = !_showTools;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Stack(children: [_buildBody(), const VersionBanner()]),
      bottomNavigationBar: const ValidationIndicator(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          const Icon(
            Icons.data_object,
            color: AppColors.primary,
            size: AppDimensions.iconSizeL,
          ),
          const SizedBox(width: AppDimensions.paddingS),
          const Text(AppStrings.appName),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.build,
            color: _showTools ? AppColors.primary : AppColors.textSecondary,
          ),
          onPressed: _toggleTools,
          tooltip: 'Advanced Tools',
        ),
        IconButton(
          icon: const Icon(Icons.info_outline),
          tooltip: 'About',
          onPressed: () async {
            await showDialog<void>(
              context: context,
              builder: (context) => const AboutAppDialog(),
            );
          },
        ),
        const SizedBox(width: AppDimensions.paddingS),
      ],
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        if (_showTools) _buildToolsPanel(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Use horizontal split for wide screens, vertical for narrow
              final isWideScreen = constraints.maxWidth > 800;

              if (isWideScreen) {
                return _buildHorizontalSplit();
              } else {
                return _buildVerticalSplit();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildToolsPanel() {
    return Container(
      height: 350,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _toolsTabController,
            tabs: const [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.analytics, size: AppDimensions.iconSizeS),
                    SizedBox(width: AppDimensions.paddingXS),
                    Text('Statistics'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.route, size: AppDimensions.iconSizeS),
                    SizedBox(width: AppDimensions.paddingXS),
                    Text('Path Query'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.compare_arrows, size: AppDimensions.iconSizeS),
                    SizedBox(width: AppDimensions.paddingXS),
                    Text('Compare'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history, size: AppDimensions.iconSizeS),
                    SizedBox(width: AppDimensions.paddingXS),
                    Text('History'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schema, size: AppDimensions.iconSizeS),
                    SizedBox(width: AppDimensions.paddingXS),
                    Text('Schema'),
                  ],
                ),
              ),
            ],
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: AppColors.border,
          ),
          Expanded(
            child: TabBarView(
              controller: _toolsTabController,
              children: const [
                JsonStatisticsPanel(),
                JsonPathQueryPanel(),
                JsonComparePanel(),
                _HistoryPlaceholder(),
                JsonSchemaPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Horizontal split layout for wide screens (desktop).
  Widget _buildHorizontalSplit() {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Row(
        children: [
          Expanded(child: JsonInputArea(key: _inputKey)),
          const SizedBox(width: AppDimensions.paddingM),
          Expanded(child: _buildOutputPanel()),
        ],
      ),
    );
  }

  /// Vertical split layout for narrow screens (mobile).
  Widget _buildVerticalSplit() {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Column(
        children: [
          Expanded(child: JsonInputArea(key: _inputKey)),
          const SizedBox(height: AppDimensions.paddingM),
          Expanded(child: _buildOutputPanel()),
        ],
      ),
    );
  }

  /// Output panel showing the JSON tree view.
  Widget _buildOutputPanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: const _TreeContent(),
    );
  }
}

/// Tree view content that handles empty / invalid / valid states.
class _TreeContent extends ConsumerWidget {
  const _TreeContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsedData = ref.watch(parsedDataProvider);
    final isValid = ref.watch(isValidProvider);
    final isEmpty = ref.watch(isEmptyProvider);
    final errorMessage = ref.watch(errorMessageProvider);

    if (!isEmpty && !isValid) {
      return _buildError(errorMessage);
    }

    if (isEmpty || parsedData == null) {
      return Center(
        child: Text(
          AppStrings.outputPlaceholder,
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: AppDimensions.fontSizeM,
            color: AppColors.textMuted,
          ),
        ),
      );
    }

    return const JsonTreeViewWidget();
  }

  Widget _buildError(String message) => ErrorDisplay.inline(message);
}

/// Placeholder widget for History feature (coming soon).
class _HistoryPlaceholder extends StatelessWidget {
  const _HistoryPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 48, color: AppColors.textMuted),
          const SizedBox(height: AppDimensions.paddingM),
          Text(
            'History feature coming soon',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: AppDimensions.fontSizeM,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppDimensions.paddingS),
          Text(
            'Track your JSON transformations',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: AppDimensions.fontSizeS,
              color: AppColors.textMuted.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
