import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

/// Text fields plus the two overlay affordances (dialog and bottom sheet).
Widget buildInputsPage(BuildContext context) {
  return ListView(
    padding: const EdgeInsets.all(SpectraSpacing.xl),
    children: <Widget>[
      const SpectraSectionHeader(title: 'Fields'),
      const SpectraTextField(label: 'Nickname', hint: 'My blue card'),
      const SizedBox(height: SpectraSpacing.md),
      const SpectraTextField(label: 'UID', errorText: 'Required'),
      const SizedBox(height: SpectraSpacing.xl),
      const SpectraSectionHeader(title: 'Overlays'),
      SpectraButton(
        label: 'Show dialog',
        variant: SpectraButtonVariant.secondary,
        onPressed: () => SpectraDialog.show<void>(
          context: context,
          title: 'Erase slot 3?',
          content: const Text('This cannot be undone.'),
          actions: (BuildContext context) => <Widget>[
            SpectraButton(
              label: 'Cancel',
              variant: SpectraButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            SpectraButton(
              label: 'Erase',
              variant: SpectraButtonVariant.danger,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
      const SizedBox(height: SpectraSpacing.md),
      SpectraButton(
        label: 'Show bottom sheet',
        variant: SpectraButtonVariant.secondary,
        onPressed: () => SpectraBottomSheet.show<void>(
          context: context,
          title: 'Slot details',
          builder: (BuildContext context) =>
              const Text('MIFARE Classic 1K, slot 3.'),
        ),
      ),
    ],
  );
}
