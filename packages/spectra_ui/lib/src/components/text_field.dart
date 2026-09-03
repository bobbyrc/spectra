import 'package:material_ui/material_ui.dart';

import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// A labelled single-line input over `material_ui`'s [TextField].
class SpectraTextField extends StatelessWidget {
  const SpectraTextField({
    required this.label,
    this.controller,
    this.hint,
    this.errorText,
    this.onChanged,
    this.obscureText = false,
    this.enabled = true,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    return Semantics(
      textField: true,
      label: label,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        obscureText: obscureText,
        enabled: enabled,
        style: SpectraTypography.body.copyWith(color: theme.colors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: errorText,
          filled: true,
          fillColor: theme.colors.surface,
          constraints: const BoxConstraints(minHeight: 48),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: SpectraSpacing.md,
            vertical: SpectraSpacing.md,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SpectraSpacing.sm),
            borderSide: BorderSide(color: theme.colors.border),
          ),
        ),
      ),
    );
  }
}
