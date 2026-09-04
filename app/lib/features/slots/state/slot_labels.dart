import 'package:chameleon/chameleon.dart';

/// The tag types the user may put in a slot, derived from the SDK's own
/// families rather than a hand-typed list.
///
/// `TagFamily.iso14443_4` and `TagFamily.seos` are excluded: the SDK has no
/// emulator support for them (`FakeFirmware._dispatch` answers the whole
/// `CommandRange.iso14443_4` range with NOT_IMPLEMENTED, and
/// `FakeFirmwareConfig.defaultCapabilities` advertises none of 6000-6005),
/// so offering them would be a type the app could set but never fill.
List<TagType> selectableTypes(Sense sense) => TagType.values
    .where(
      (TagType t) =>
          t != TagType.undefined &&
          switch (sense) {
            Sense.hf =>
              t.family == TagFamily.mifareClassic ||
                  t.family == TagFamily.ultralight,
            Sense.lf => t.family == TagFamily.lf,
            Sense.none => false,
          },
    )
    .toList(growable: false);
