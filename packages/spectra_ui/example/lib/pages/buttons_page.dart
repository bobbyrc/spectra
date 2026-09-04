import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

/// Every button variant and state, with sample labels.
Widget buildButtonsPage(BuildContext context) {
  return ListView(
    padding: const EdgeInsets.all(SpectraSpacing.xl),
    children: <Widget>[
      const SpectraSectionHeader(title: 'Variants'),
      SpectraButton(label: 'Connect', onPressed: () {}),
      const SizedBox(height: SpectraSpacing.md),
      SpectraButton(
        label: 'Rescan',
        variant: SpectraButtonVariant.secondary,
        onPressed: () {},
      ),
      const SizedBox(height: SpectraSpacing.md),
      SpectraButton(
        label: 'Erase slot',
        variant: SpectraButtonVariant.danger,
        icon: Icons.delete_outline,
        onPressed: () {},
      ),
      const SizedBox(height: SpectraSpacing.xl),
      const SpectraSectionHeader(title: 'States'),
      const SpectraButton(label: 'Disabled', onPressed: null),
      const SizedBox(height: SpectraSpacing.md),
      SpectraButton(label: 'Working', busy: true, onPressed: () {}),
    ],
  );
}
