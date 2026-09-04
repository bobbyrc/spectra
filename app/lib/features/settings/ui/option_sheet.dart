import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

/// One radio-style chooser for every enum on the settings screen: the
/// animation mode, four button functions and the sleep timeout all pick one
/// value out of a short list, and five bespoke sheets would be five places
/// for the same layout to drift.
///
/// Resolves to the chosen value, or null when dismissed.
Future<T?> showOptionSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> options,
  required String Function(T option) labelOf,
  T? selected,
}) => SpectraBottomSheet.show<T>(
  context: context,
  title: title,
  builder: (BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (final T option in options)
        SpectraListTile(
          title: labelOf(option),
          trailing: option == selected ? const Icon(Icons.check) : null,
          onTap: () => Navigator.of(context).pop(option),
        ),
    ],
  ),
);
