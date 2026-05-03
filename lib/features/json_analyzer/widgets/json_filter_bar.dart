import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/json_key_collector.dart';
import '../models/search_filter.dart';

// ---------------------------------------------------------------------------
// Module-level helpers
// ---------------------------------------------------------------------------

Color _typeColor(ValueType type) => switch (type) {
      ValueType.string => AppColors.jsonString,
      ValueType.number => AppColors.jsonNumber,
      ValueType.boolean => AppColors.jsonBoolean,
      ValueType.nullValue => AppColors.jsonNull,
      ValueType.datetime => AppColors.accent,
      ValueType.any => AppColors.textMuted,
    };

Widget _chipValueText(SearchFilter filter) {
  if (filter.valueType == ValueType.nullValue) {
    return Text(
      'null',
      style: GoogleFonts.jetBrainsMono(
        fontSize: AppDimensions.fontSizeS,
        color: AppColors.jsonNull,
        fontStyle: FontStyle.italic,
      ),
    );
  }
  final color = switch (filter.valueType) {
    ValueType.number => AppColors.jsonNumber,
    ValueType.boolean => AppColors.jsonBoolean,
    ValueType.datetime => AppColors.accent,
    _ => AppColors.jsonString,
  };
  // For datetime: show the custom pattern if provided, otherwise format label.
  final String suffix;
  if (filter.valueType == ValueType.datetime) {
    final pat = filter.customDatePattern.trim();
    suffix = filter.dateTimeFormat == DateTimeFormat.custom && pat.isNotEmpty
        ? ' [$pat]'
        : ' [${filter.dateTimeFormat.label}]';
  } else {
    suffix = '';
  }
  return Text(
    '"${filter.value}"$suffix',
    style: GoogleFonts.jetBrainsMono(
      fontSize: AppDimensions.fontSizeS,
      color: color,
    ),
  );
}

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

  /// Index of the condition being edited, or -1 when adding a new one.
  int _editingIndex = -1;

  void _remove(int index) {
    widget.onFiltersChanged([...widget.filters]..removeAt(index));
    // Close form if the removed chip was the one being edited.
    if (_editingIndex == index) {
      setState(() {
        _showForm = false;
        _editingIndex = -1;
      });
    }
  }

  void _toggle(int index) {
    final updated = [...widget.filters];
    updated[index] = updated[index].toggleEnabled();
    widget.onFiltersChanged(updated);
  }

  void _clearAll() {
    widget.onFiltersChanged(const []);
    setState(() {
      _showForm = false;
      _editingIndex = -1;
    });
  }

  /// Opens the form to edit chip at [index].
  /// Tapping the same chip again closes the form.
  void _startEdit(int index) {
    setState(() {
      if (_showForm && _editingIndex == index) {
        _showForm = false;
        _editingIndex = -1;
      } else {
        _showForm = true;
        _editingIndex = index;
      }
    });
  }

  void _addOrEdit(SearchFilter filter) {
    final updated = [...widget.filters];
    if (_editingIndex >= 0 && _editingIndex < updated.length) {
      updated[_editingIndex] = filter;
    } else {
      updated.add(filter);
    }
    widget.onFiltersChanged(updated);
    setState(() {
      _showForm = false;
      _editingIndex = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _editingIndex >= 0;
    final initialFilter =
        isEditing ? widget.filters[_editingIndex] : null;

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
                        isEditing: _editingIndex == e.key && _showForm,
                        onEdit: () => _startEdit(e.key),
                        onToggle: () => _toggle(e.key),
                        onRemove: () => _remove(e.key),
                      ),
                    ),
                _AddButton(
                  active: _showForm && !isEditing,
                  onTap: () => setState(() {
                    if (_showForm && !isEditing) {
                      _showForm = false;
                    } else {
                      _showForm = true;
                      _editingIndex = -1;
                    }
                  }),
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
          // ── Add / Edit condition inline form ───────────────────────────
          if (_showForm)
            _AddConditionForm(
              key: ValueKey(_editingIndex), // rebuild when switching chips
              keySuggestions: widget.keySuggestions,
              initialFilter: initialFilter,
              isEditing: isEditing,
              onAdd: _addOrEdit,
              onCancel: () => setState(() {
                _showForm = false;
                _editingIndex = -1;
              }),
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
  final bool isEditing;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  const _FilterChip({
    required this.filter,
    required this.index,
    required this.total,
    required this.isEditing,
    required this.onEdit,
    required this.onToggle,
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
                color: filter.enabled
                    ? AppColors.textMuted
                    : AppColors.textMuted.withValues(alpha: 0.4),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Opacity(
          opacity: filter.enabled ? 1.0 : 0.45,
          child: GestureDetector(
            onTap: onEdit,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isEditing
                    ? AppColors.primary.withValues(alpha: 0.22)
                    : AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                border: Border.all(
                  color: isEditing
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.4),
                  width: isEditing ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Toggle on/off button.
                  GestureDetector(
                    onTap: onToggle,
                    child: Tooltip(
                      message: filter.enabled ? 'Disable condition' : 'Enable condition',
                      child: Icon(
                        filter.enabled
                            ? Icons.toggle_on
                            : Icons.toggle_off,
                        size: 16,
                        color: filter.enabled
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (isEditing) ...[
                    const Icon(Icons.edit, size: 10, color: AppColors.primary),
                    const SizedBox(width: 4),
                  ],
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
                  _chipValueText(filter),
                  if (filter.valueType != ValueType.any) ...[
                    const SizedBox(width: 4),
                    Text(
                      filter.valueType.label,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        color: _typeColor(filter.valueType),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (filter.caseSensitive) ...[
                    const SizedBox(width: 3),
                    Text(
                      'Aa',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
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
          ),
        ), // closes Opacity
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

  /// When non-null the form is pre-filled with these values for editing.
  final SearchFilter? initialFilter;

  /// `true` when editing an existing condition (changes button label to "Save").
  final bool isEditing;

  const _AddConditionForm({
    super.key,
    required this.keySuggestions,
    required this.onAdd,
    required this.onCancel,
    this.initialFilter,
    this.isEditing = false,
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
  final TextEditingController _patternController = TextEditingController();

  ValueType _valueType = ValueType.any;
  FilterOperator _operator = FilterOperator.contains;
  bool _caseSensitive = false;
  DateTimeFormat _dateTimeFormat = DateTimeFormat.iso8601;
  List<String> _valueSamples = [];

  @override
  void initState() {
    super.initState();
    // Pre-fill when editing an existing condition.
    final initial = widget.initialFilter;
    if (initial != null) {
      _valueType = initial.valueType;
      _operator = initial.operator;
      _caseSensitive = initial.caseSensitive;
      _dateTimeFormat = initial.dateTimeFormat;
      _keyController.text = initial.key;
      _valueController.text = initial.value;
      _patternController.text = initial.customDatePattern;
    }
    _keyController.addListener(_onTextChanged);
    _valueController.addListener(_onTextChanged);
    _patternController.addListener(_onTextChanged);
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
    _patternController
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }

  // Called when user picks a suggestion from the dropdown.
  void _onSuggestionSelected(KeySuggestion suggestion) {
    setState(() => _valueSamples = suggestion.sampleValues);
    _valueFocus.requestFocus();
  }

  void _setValueType(ValueType type) {
    setState(() {
      _valueType = type;
      // Reset operator to first available for the new type.
      final ops = type.availableOperators;
      if (!ops.contains(_operator)) _operator = ops.first;
      // Pre-fill boolean value with 'true' for convenience.
      if (type == ValueType.boolean && _valueController.text.isEmpty) {
        _valueController.text = 'true';
      }
      // Null type needs no value — clear input.
      if (type == ValueType.nullValue) _valueController.clear();
      // Pre-fill datetime with format example as hint placeholder.
      if (type == ValueType.datetime) _valueController.clear();
    });
  }

  bool get _canSubmit {
    if (_keyController.text.trim().isEmpty) return false;
    if (_valueType == ValueType.nullValue) return true;
    if (_valueController.text.trim().isEmpty) return false;
    // Custom datetime format requires a non-empty pattern.
    if (_valueType == ValueType.datetime &&
        _dateTimeFormat == DateTimeFormat.custom &&
        _patternController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  void _submit() {
    if (!_canSubmit) return;
    widget.onAdd(SearchFilter(
      key: _keyController.text.trim(),
      operator: _operator,
      value: _valueType == ValueType.nullValue ? '' : _valueController.text.trim(),
      valueType: _valueType,
      caseSensitive: _caseSensitive,
      dateTimeFormat: _dateTimeFormat,
      customDatePattern: _patternController.text.trim(),
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
          // ── Step 1: Key ───────────────────────────────────────────────
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
          // ── Step 2: Value type ────────────────────────────────────────
          const _SectionLabel(label: 'Type'),
          const SizedBox(height: 4),
          _ValueTypeSelector(
            selected: _valueType,
            onChanged: _setValueType,
          ),
          const SizedBox(height: AppDimensions.paddingS),
          // ── Step 3: Operator (adapts to type) ─────────────────────────
          const _SectionLabel(label: 'Operator'),
          const SizedBox(height: 4),
          _OperatorSelector(
            selected: _operator,
            available: _valueType.availableOperators,
            onChanged: (op) => setState(() => _operator = op),
          ),
          // ── DateTime format selector (only for datetime type) ─────────
          if (_valueType == ValueType.datetime) ...[
            const SizedBox(height: AppDimensions.paddingS),
            const _SectionLabel(label: 'Format'),
            const SizedBox(height: 4),
            _DateTimeFormatSelector(
              selected: _dateTimeFormat,
              onChanged: (f) => setState(() {
                _dateTimeFormat = f;
                _valueController.clear();
                if (f != DateTimeFormat.custom) _patternController.clear();
              }),
            ),
            // Custom pattern input — shown only when Custom format selected.
            if (_dateTimeFormat == DateTimeFormat.custom) ...[
              const SizedBox(height: AppDimensions.paddingS),
              _CustomPatternInput(controller: _patternController),
            ],
          ],
          const SizedBox(height: AppDimensions.paddingS),
          // ── Step 4: Value input (adapts to type) ──────────────────────
          if (_valueType != ValueType.nullValue) ...[
            Row(
              children: [
                const _SectionLabel(label: 'Value'),
                const Spacer(),
                if (_valueType == ValueType.string ||
                    _valueType == ValueType.any)
                  _CaseSensitiveToggle(
                    value: _caseSensitive,
                    onChanged: (v) => setState(() => _caseSensitive = v),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (_valueType == ValueType.boolean)
              _BooleanToggle(
                value: _valueController.text == 'true',
                onChanged: (v) {
                  _valueController.text = v ? 'true' : 'false';
                },
              )
            else
              _ValueInput(
                controller: _valueController,
                focusNode: _valueFocus,
                samples: _valueType == ValueType.number ||
                        _valueType == ValueType.any
                    ? _valueSamples
                    : _valueSamples
                        .where((s) =>
                            double.tryParse(s) == null &&
                            s != 'true' &&
                            s != 'false' &&
                            s != 'null')
                        .toList(),
                keyboardType: (_valueType == ValueType.number ||
                        _valueType == ValueType.datetime)
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                hintText: _valueType == ValueType.datetime
                    ? _dateTimeFormat.example
                    : 'Enter value…',
                onSampleTap: (s) {
                  _valueController.text = s;
                  _valueController.selection =
                      TextSelection.collapsed(offset: s.length);
                },
                onSubmit: _submit,
              ),
          ] else ...[
            const _SectionLabel(label: 'Value'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusS),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'Matches fields whose value is null',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: AppDimensions.fontSizeS,
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
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
                  widget.isEditing ? 'Save' : 'Add',
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

// ---------------------------------------------------------------------------
// Value-type selector
// ---------------------------------------------------------------------------

class _ValueTypeSelector extends StatelessWidget {
  final ValueType selected;
  final ValueChanged<ValueType> onChanged;

  const _ValueTypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: ValueType.values.map((type) {
        final isSelected = type == selected;
        final color = _typeColor(type);
        return GestureDetector(
          onTap: () => onChanged(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              border: Border.all(
                color: isSelected ? color : AppColors.border,
              ),
            ),
            child: Text(
              type.label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: isSelected ? color : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom datetime pattern input
// ---------------------------------------------------------------------------

/// Text field for entering a custom `intl` DateFormat pattern together with
/// a quick-reference guide of the most common pattern tokens.
class _CustomPatternInput extends StatelessWidget {
  final TextEditingController controller;

  const _CustomPatternInput({required this.controller});

  static const _tokenRef = [
    ('yyyy', 'year'),
    ('MM', 'month'),
    ('dd', 'day'),
    ('HH', 'hour 24h'),
    ('mm', 'minute'),
    ('ss', 'second'),
    ('a', 'AM/PM'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          style: GoogleFonts.jetBrainsMono(
            fontSize: AppDimensions.fontSizeS,
            color: AppColors.accent,
          ),
          decoration: InputDecoration(
            hintText: 'e.g. dd/MM/yyyy  or  MM-dd-yyyy HH:mm',
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
              borderSide: const BorderSide(color: AppColors.accent),
            ),
            isDense: true,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 2,
          children: _tokenRef.map((t) {
            return RichText(
              text: TextSpan(
                style: GoogleFonts.jetBrainsMono(fontSize: 10),
                children: [
                  TextSpan(
                    text: t.$1,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: '=${t.$2}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Boolean toggle
// ---------------------------------------------------------------------------

class _BooleanToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BooleanToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _boolChip(label: 'true', selected: value, onTap: () => onChanged(true)),
        const SizedBox(width: 6),
        _boolChip(label: 'false', selected: !value, onTap: () => onChanged(false)),
      ],
    );
  }

  Widget _boolChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.jsonBoolean.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
          border: Border.all(
            color: selected ? AppColors.jsonBoolean : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: AppDimensions.fontSizeS,
            color: selected ? AppColors.jsonBoolean : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Operator selector
// ---------------------------------------------------------------------------

class _OperatorSelector extends StatelessWidget {
  final FilterOperator selected;
  final List<FilterOperator> available;
  final ValueChanged<FilterOperator> onChanged;

  const _OperatorSelector({
    required this.selected,
    required this.available,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: available.map((op) {
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
  final TextInputType keyboardType;
  final String hintText;

  const _ValueInput({
    required this.controller,
    required this.focusNode,
    required this.samples,
    required this.onSampleTap,
    required this.onSubmit,
    this.keyboardType = TextInputType.text,
    this.hintText = 'Enter value…',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          onSubmitted: (_) => onSubmit(),
          style: GoogleFonts.jetBrainsMono(
            fontSize: AppDimensions.fontSizeS,
            color: AppColors.jsonString,
          ),
          decoration: InputDecoration(
            hintText: hintText,
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
// DateTime format selector
// ---------------------------------------------------------------------------

class _DateTimeFormatSelector extends StatelessWidget {
  final DateTimeFormat selected;
  final ValueChanged<DateTimeFormat> onChanged;

  const _DateTimeFormatSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 4,
          children: DateTimeFormat.values.map((fmt) {
            final isSelected = fmt == selected;
            return GestureDetector(
              onTap: () => onChanged(fmt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accent.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusS),
                  border: Border.all(
                    color: isSelected ? AppColors.accent : AppColors.border,
                  ),
                ),
                child: Text(
                  fmt.label,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: isSelected
                        ? AppColors.accent
                        : AppColors.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        Text(
          '${selected.description}  •  e.g. ${selected.example}',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Case-sensitive toggle
// ---------------------------------------------------------------------------

/// Small `Aa` toggle that appears next to the Value label.
class _CaseSensitiveToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CaseSensitiveToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Tooltip(
        message: value ? 'Case-sensitive: ON' : 'Case-sensitive: OFF',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: value
                ? AppColors.primary.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            border: Border.all(
              color: value ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            'Aa',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: value ? AppColors.primary : AppColors.textMuted,
              fontWeight: value ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
      ),
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
