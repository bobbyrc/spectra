import 'package:material_ui/material_ui.dart';

import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// A labelled single-line input over `material_ui`'s [TextField].
///
/// The field carries no `Semantics` wrapper of its own: [TextField] already
/// publishes a text-field node, and [InputDecoration.labelText] becomes that
/// node's label, so wrapping it would announce the label twice. Pass
/// [semanticsLabel] only when the visible label is not what a screen reader
/// should read.
class SpectraTextField extends StatelessWidget {
  const SpectraTextField({
    required this.label,
    this.controller,
    this.hint,
    this.errorText,
    this.onChanged,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.readOnly = false,
    this.semanticsLabel,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Shows the value but takes no edits; unlike `enabled: false` it stays
  /// focusable and selectable.
  final bool readOnly;

  /// Overrides what a screen reader announces for the field. Null keeps the
  /// visible [label].
  final String? semanticsLabel;

  /// The minimum tap target, per spec 6.2's 48px rule.
  static const double minTargetSize = 48;

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final String? override = semanticsLabel;
    final Widget field = TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      obscureText: obscureText,
      enabled: enabled,
      readOnly: readOnly,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      focusNode: focusNode,
      autofocus: autofocus,
      style: SpectraTypography.body.copyWith(color: theme.colors.textPrimary),
      decoration: InputDecoration(
        // When the caller overrides the announcement, the visible label is
        // hidden from semantics so only one label reaches the node.
        label: override == null ? null : ExcludeSemantics(child: Text(label)),
        labelText: override == null ? label : null,
        hintText: hint,
        errorText: errorText,
        filled: true,
        fillColor: theme.colors.surface,
        constraints: const BoxConstraints(minHeight: minTargetSize),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SpectraSpacing.md,
          vertical: SpectraSpacing.md,
        ),
        // borderStrong, not border: the field's outline is the affordance,
        // so it has to clear WCAG 1.4.11's 3:1 non-text contrast.
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SpectraSpacing.sm),
          borderSide: BorderSide(color: theme.colors.borderStrong),
        ),
      ),
    );
    if (override == null) return field;
    return Semantics(label: override, child: field);
  }
}
