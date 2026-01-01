import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../version_check/about_dialog.dart';
import '../../version_check/version_banner.dart';
import '../../version_check/version_notifier.dart';
import '../providers/json_analyzer_provider.dart';
import '../widgets/advanced_toolbar.dart';
import '../widgets/json_compare_panel.dart';
import '../widgets/json_input_area.dart';
import '../widgets/json_output_area.dart';
import '../widgets/json_path_query_panel.dart';
import '../widgets/json_search_panel.dart';
import '../widgets/json_statistics_panel.dart';
import '../widgets/json_tree_view.dart';
import '../widgets/toolbar.dart';
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
    with TickerProviderStateMixin {
  late final TabController _outputTabController;
  late final TabController _toolsTabController;
  bool _showSearch = false;
  bool _showTools = false;

  @override
  void initState() {
    super.initState();
    _outputTabController = TabController(length: 2, vsync: this);
    _toolsTabController = TabController(length: 4, vsync: this);
    _outputTabController.addListener(_onTabChanged);

    // Trigger a background version check (non-blocking)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: unused_result
      ref.read(versionNotifierProvider.notifier).checkForUpdateIfConnected();
    });
  }

  @override
  void dispose() {
    _outputTabController.removeListener(_onTabChanged);
    _outputTabController.dispose();
    _toolsTabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_outputTabController.indexIsChanging) {
      ref
          .read(jsonAnalyzerProvider.notifier)
          .setSelectedTab(_outputTabController.index);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppDimensions.paddingM),
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (_showSearch) _showTools = false;
    });
  }

  void _toggleTools() {
    setState(() {
      _showTools = !_showTools;
      if (_showTools) _showSearch = false;
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
            Icons.search,
            color: _showSearch ? AppColors.primary : AppColors.textSecondary,
          ),
          onPressed: _toggleSearch,
          tooltip: 'Search in JSON',
        ),
        IconButton(
          icon: Icon(
            Icons.build,
            color: _showTools ? AppColors.primary : AppColors.textSecondary,
          ),
          onPressed: _toggleTools,
          tooltip: 'Advanced Tools',
        ),
        IconButton(
          icon: const Icon(Icons.system_update_alt),
          tooltip: 'Check for updates',
          onPressed: () async {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Checking for updates...')),
            );
            await ref
                .read(versionNotifierProvider.notifier)
                .checkForUpdateIfConnected(force: true);
            if (!mounted) return;
            final st = ref.read(versionNotifierProvider);
            if (st.hasNew) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('A new version is available')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('You are up to date')),
              );
            }
          },
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
        Toolbar(onShowMessage: _showMessage),
        AdvancedToolbar(onShowMessage: _showMessage),
        if (_showSearch) const JsonSearchPanel(),
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
          const Expanded(child: JsonInputArea()),
          const SizedBox(width: AppDimensions.paddingM),
          Expanded(child: _buildOutputTabs()),
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
          const Expanded(child: JsonInputArea()),
          const SizedBox(height: AppDimensions.paddingM),
          Expanded(child: _buildOutputTabs()),
        ],
      ),
    );
  }

  /// Output area with tabs for Formatted and Tree View.
  Widget _buildOutputTabs() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildTabBar(),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _outputTabController,
              children: const [_FormattedTabContent(), _TreeViewTabContent()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusM),
        ),
      ),
      child: TabBar(
        controller: _outputTabController,
        tabs: const [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.code, size: AppDimensions.iconSizeS),
                SizedBox(width: AppDimensions.paddingXS),
                Text(AppStrings.formattedTab),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_tree, size: AppDimensions.iconSizeS),
                SizedBox(width: AppDimensions.paddingXS),
                Text(AppStrings.treeViewTab),
              ],
            ),
          ),
        ],
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
      ),
    );
  }
}

/// Content for the Formatted JSON tab without header.
class _FormattedTabContent extends ConsumerWidget {
  const _FormattedTabContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final output = ref.watch(outputProvider);
    final isValid = ref.watch(isValidProvider);
    final isEmpty = ref.watch(isEmptyProvider);
    final errorMessage = ref.watch(errorMessageProvider);

    return _OutputContent(
      output: output,
      isValid: isValid,
      isEmpty: isEmpty,
      errorMessage: errorMessage,
      child: const JsonOutputArea(),
    );
  }
}

/// Content for the Tree View tab without header.
class _TreeViewTabContent extends ConsumerWidget {
  const _TreeViewTabContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isValid = ref.watch(isValidProvider);
    final isEmpty = ref.watch(isEmptyProvider);

    return _OutputContent(
      output: '',
      isValid: isValid,
      isEmpty: isEmpty,
      errorMessage: '',
      child: const JsonTreeViewWidget(),
    );
  }
}

/// Wrapper for output content that handles the container styling.
class _OutputContent extends StatelessWidget {
  final String output;
  final bool isValid;
  final bool isEmpty;
  final String errorMessage;
  final Widget child;

  const _OutputContent({
    required this.output,
    required this.isValid,
    required this.isEmpty,
    required this.errorMessage,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Return the child without the outer container since tabs handle it
    if (child is JsonOutputArea) {
      return _FormattedContent(
        output: output,
        isValid: isValid,
        isEmpty: isEmpty,
        errorMessage: errorMessage,
      );
    }

    return _TreeContent(isValid: isValid, isEmpty: isEmpty);
  }
}

/// Formatted JSON content without container.
class _FormattedContent extends ConsumerWidget {
  final String output;
  final bool isValid;
  final bool isEmpty;
  final String errorMessage;

  const _FormattedContent({
    required this.output,
    required this.isValid,
    required this.isEmpty,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final output = ref.watch(outputProvider);
    final isValid = ref.watch(isValidProvider);
    final isEmpty = ref.watch(isEmptyProvider);
    final errorMessage = ref.watch(errorMessageProvider);

    if (isEmpty) {
      return _buildPlaceholder();
    }

    if (!isValid) {
      return _buildError(errorMessage);
    }

    return _buildHighlightedJson(output);
  }

  Widget _buildPlaceholder() {
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

  Widget _buildError(String errorMessage) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: AppDimensions.iconSizeM,
              ),
              const SizedBox(width: AppDimensions.paddingS),
              Text(
                AppStrings.parseError,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: AppDimensions.fontSizeM,
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingS),
          Text(
            errorMessage,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: AppDimensions.fontSizeS,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedJson(String output) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: SelectableText(
        output,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: AppDimensions.fontSizeM,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
      ),
    );
  }
}

/// Tree view content without container.
class _TreeContent extends ConsumerWidget {
  final bool isValid;
  final bool isEmpty;

  const _TreeContent({required this.isValid, required this.isEmpty});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsedData = ref.watch(parsedDataProvider);
    final isValid = ref.watch(isValidProvider);
    final isEmpty = ref.watch(isEmptyProvider);

    if (isEmpty || !isValid || parsedData == null) {
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
