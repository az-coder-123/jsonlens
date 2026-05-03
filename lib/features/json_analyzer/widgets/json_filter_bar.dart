import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/json_key_collector.dart';
import '../models/search_filter.dart';

/// Filter bar for structured key-value object search.
///
/// Displays [SearchFilter] chips and provides an inline form for adding new
/// conditions. All active conditions are ANDed together during matching.
class JsonFilterBar extends StatefulWidget {
  final List<KeySuggestion> keySuggestions;
  final List<SearchFilter> filters;
  final ValueChanged<List<SearchFilter>> onFiltersChanged;

  /// Whether the results are currently shown as a flat list (`true`) or as
  /// a tree view (`false`). Drives the list/tree toggle button label.
  final bool showList;

  /// Called when the user taps the list/tree toggle button.
  final VoidCallback onToggleView;

  const JsonFilterBar({
    super.key,
    required this.keySuggestions,
    required this.filters,
    required this.onFiltersChanged,
    required this.showList,
    required this.onToggleView,
  });

  @override
  State<JsonFilterBar> createState() => _JsonFilterBarState();
}

class _JsonFilterBarState extends State<JsonFilterBar> {
  bool _showForm = false;

  void _remove(int index) =>
      widget.onFiltersChanged([...widget.filters]..removeAt(index));

  void _clearAll() => widget.onFiltersChanged(const []);

  void _add(SearchFilter filter) {
    widget.onFiltersChanged([...widget.filters, filter]);
    setState(() => _showForm = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Chips row ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingM,
              vertical: AppDimensions.paddingS,
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...widget.filters.asMap().entries.map(
                      (e) => _FilterChip(
                        filter: e.value,
                        index: e.key,
                        total: widget.filters.length,
                        onRemove: () => _remove(e.key),
                      ),
                    ),
                _AddButton(
                  active: _showForm,
                  onTap: () => setState(() => _showForm = !_showForm),
                ),
                if (widget.filters.isNotEmpty) ...[
                  _ClearAllButton(onTap: _clearAll),
                  _ViewToggleButton(
                    showList: widget.showList,
                    onTap: widget.onToggleView,
                  ),
                ],
              ],
            ),
          ),
          // ── Add-condition inline form ───────────────────────────────────
          if (_showForm)
            _AddConditionForm(
              keySuggestions: widget.keySuggestions,
              onAdd: _add,
              onCancel: () => setState(() => _showForm = false),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Active filter chip
// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  final SearchFilter filter;
  final int index;
  final int total;
  final VoidCallback onRemove;

  const _FilterChip({
    required this.filter,
    required this.index,
    required this.total,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // AND label between chips
        if (index > 0)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              'AND',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                filter.key,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: AppDimensions.fontSizeS,
                  color: AppColors.jsonKey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  filter.operator.label,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Text(
                '"${filter.value}"',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: AppDimensions.fontSizeS,
                  color: AppColors.jsonString,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(
                  Icons.close,
                  size: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Add / Clear buttons
// ---------------------------------------------------------------------------

class _AddButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _AddButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.remove : Icons.add,
              size: 12,
              color: active ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              'Add condition',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: active ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClearAllButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ClearAllButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        'Clear all',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          color: AppColors.textMuted,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// Toggles between the flat results list and the tree view.
class _ViewToggleButton extends StatelessWidget {
  final bool showList;
  final VoidCallback onTap;

  const _ViewToggleButton({required this.showList, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: showList ? 'Switch to tree view' : 'Show results list',
        child: Icon(
          showList ? Icons.account_tree_outlined : Icons.format_list_bulleted,
          size: 14,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add-condition form
// ---------------------------------------------------------------------------

class _AddConditionForm extends StatefulWidget {
  final List<KeySuggestion> keySuggestions;
  final ValueChanged<SearchFilter> onAdd;
  final VoidCallback onCancel;

  const _AddConditionForm({
    required this.keySuggestions,
    required this.onAdd,
    required this.onCancel,
  });

  @override
  State<_AddConditionForm> createState() => _AddConditionFormState();
}

class _AddConditionFormState extends State<_AddConditionForm> {
  // _keyController is owned here so we can always read the typed text,
  // regardless of whether the user picked from the dropdown or typed freely.
  final TextEditingController _keyController = TextEditingController();
  final FocusNode _keyFocus = FocusNode();
  final TextEditingController _valueController = TextEditingController();
  final FocusNode _valueFocus = FocusNode();

  FilterOperator _operator = FilterOperator.contains;
  List<String> _valueSamples = [];

  @override
  void initState() {
    super.initState();
    // Rebuild whenever key or value text changes so button state is accurate.
    _keyController.addListener(_onTextChanged);
    _valueController.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _keyController
      ..removeListener(_onTextChanged)
      ..dispose();
    _keyFocus.dispose();
    _valueController
      ..removeListener(_onTextChanged)
      ..dispose();
    _valueFocus.dispose();
    super.dispose();
  }

  // Called when user picks a suggestion from the dropdown.
  void _onSuggestionSelected(KeySuggestion suggestion) {
    setState(() => _valueSamples = suggestion.sampleValues);
    _valueFocus.requestFocus();
  }

  bool get _canSubmit =>
      _keyController.text.trim().isNotEmpty &&
      _valueController.text.trim().isNotEmpty;

  void _submit() {
    if (!_canSubmit) return;
    widget.onAdd(SearchFilter(
      key: _keyController.text.trim(),
      operator: _operator,
      value: _valueController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(
        left: AppDimensions.paddingM,
        right: AppDimensions.paddingM,
        bottom: AppDimensions.paddingS,
      ),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Step 1: Key autocomplete ──────────────────────────────────
          const _SectionLabel(label: 'Key'),
          const SizedBox(height: 4),
          _KeyAutocomplete(
            suggestions: widget.keySuggestions,
            controller: _keyController,
            focusNode: _keyFocus,
            onSuggestionSelected: _onSuggestionSelected,
            onSubmit: () => _valueFocus.requestFocus(),
          ),
          const SizedBox(height: AppDimensions.paddingS),
          // ── Step 2: Operator selector ─────────────────────────────────
          const _SectionLabel(label: 'Operator'),
          const SizedBox(height: 4),
          _OperatorSelector(
            selected: _operator,
            onChanged: (op) => setState(() => _operator = op),
          ),
          const SizedBox(height: AppDimensions.paddingS),
          // ── Step 3: Value input ───────────────────────────────────────
          const _SectionLabel(label: 'Value'),
          const SizedBox(height: 4),
          _ValueInput(
            controller: _valueController,
            focusNode: _valueFocus,
            samples: _valueSamples,
            onSampleTap: (s) {
              _valueController.text = s;
              _valueController.selection =
                  TextSelection.collapsed(offset: s.length);
            },
            onSubmit: _submit,
          ),
          const SizedBox(height: AppDimensions.paddingM),
          // ── Actions ───────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.jetBrainsMono(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusS),
                  ),
                ),
                child: Text(
                  'Add',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Key autocomplete
// ---------------------------------------------------------------------------

/// Key input with autocomplete dropdown.
///
/// Uses [RawAutocomplete] so the parent owns [controller] and can always read
/// the typed text — even when the user types a key manually without picking
/// from the suggestion list.
class _KeyAutocomplete extends StatelessWidget {
  final List<KeySuggestion> suggestions;
  final TextEditingController controller;
  final FocusNode focusNode;

  /// Called when the user picks a suggestion — provides sample values.
  final ValueChanged<KeySuggestion> onSuggestionSelected;

  /// Called when the user presses Enter in the key field.
  final VoidCallback onSubmit;

  const _KeyAutocomplete({
    required this.suggestions,
    required this.controller,
    required this.focusNode,
    required this.onSuggestionSelected,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<KeySuggestion>(
      textEditingController: controller,
      focusNode: focusNode,
      displayStringForOption: (s) => s.key,
      optionsBuilder: (value) {
        final q = value.text.toLowerCase();
        if (q.isEmpty) return suggestions.take(8);
        return suggestions
            .where((s) => s.key.toLowerCase().contains(q))
            .take(8);
      },
      fieldViewBuilder: (ctx, ctrl, fn, onSubmitted) {
        return TextField(
          controller: ctrl,
          focusNode: fn,
          onSubmitted: (_) => onSubmit(),
          style: GoogleFonts.jetBrainsMono(
            fontSize: AppDimensions.fontSizeS,
            color: AppColors.jsonKey,
          ),
          decoration: InputDecoration(
            hintText: 'Type or select a key name…',
            hintStyle: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeS,
              color: AppColors.textMuted,
            ),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            isDense: true,
            prefixIcon: const Icon(
              Icons.vpn_key_outlined,
              size: 14,
              color: AppColors.textMuted,
            ),
          ),
        );
      },
      optionsViewBuilder: (ctx, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: AppColors.surface,
            elevation: 4,
            borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxHeight: 220, maxWidth: 320),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final s = options.elementAt(i);
                  return InkWell(
                    onTap: () {
                      onSelected(s);
                      onSuggestionSelected(s);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.key,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: AppDimensions.fontSizeS,
                                color: AppColors.jsonKey,
                              ),
                            ),
                          ),
                          Text(
                            '×${s.count}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Operator selector
// ---------------------------------------------------------------------------

class _OperatorSelector extends StatelessWidget {
  final FilterOperator selected;
  final ValueChanged<FilterOperator> onChanged;

  const _OperatorSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: FilterOperator.values.map((op) {
        final isSelected = op == selected;
        return GestureDetector(
          onTap: () => onChanged(op),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              op.label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Value input with sample chips
// ---------------------------------------------------------------------------

class _ValueInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> samples;
  final ValueChanged<String> onSampleTap;
  final VoidCallback onSubmit;

  const _ValueInput({
    required this.controller,
    required this.focusNode,
    required this.samples,
    required this.onSampleTap,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          onSubmitted: (_) => onSubmit(),
          style: GoogleFonts.jetBrainsMono(
            fontSize: AppDimensions.fontSizeS,
            color: AppColors.jsonString,
          ),
          decoration: InputDecoration(
            hintText: 'Enter value…',
            hintStyle: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeS,
              color: AppColors.textMuted,
            ),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            isDense: true,
          ),
        ),
        if (samples.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: samples.map((s) {
              return GestureDetector(
                onTap: () => onSampleTap(s),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusS),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    s.length > 24 ? '${s.substring(0, 24)}…' : s,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: AppColors.jsonString,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        color: AppColors.textMuted,
      ),
    );
  }
}
