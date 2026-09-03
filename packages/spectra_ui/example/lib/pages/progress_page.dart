import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

/// Progress bars, an indeterminate variant, and step indicators.
Widget buildProgressPage(BuildContext context) {
  const List<String> steps = <String>['Prepare', 'Transfer', 'Verify'];
  return ListView(
    padding: const EdgeInsets.all(SpectraSpacing.xl),
    children: <Widget>[
      const SpectraSectionHeader(title: 'Progress'),
      SpectraProgressIndicator(
        label: 'Writing dump',
        value: 0.4,
        detail: '4 of 10 sectors',
        onCancel: () {},
      ),
      const SizedBox(height: SpectraSpacing.lg),
      const SpectraProgressIndicator(label: 'Scanning for tags'),
      const SizedBox(height: SpectraSpacing.xl),
      const SpectraSectionHeader(title: 'Steps'),
      const SpectraStepIndicator(steps: steps, currentIndex: 1),
      const SizedBox(height: SpectraSpacing.lg),
      const SpectraStepIndicator(steps: steps, currentIndex: 1, failed: true),
    ],
  );
}
