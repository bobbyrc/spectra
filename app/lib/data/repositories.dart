import 'package:chameleon/chameleon.dart';

import 'models/key_dictionary.dart';
import 'models/known_device.dart';
import 'models/saved_card.dart';

/// Devices the app has connected to before (spec 4.2, spec 8.6). Every
/// repository is declared as an interface so features depend on it, not on
/// Drift.
abstract interface class KnownDevicesRepository {
  Future<List<KnownDevice>> all();
  Future<KnownDevice?> byIdentity(DeviceIdentity identity);

  /// The most recently seen device, for "Reconnect to last device" (spec
  /// 4.2).
  Future<KnownDevice?> lastSeen();
  Future<void> remember({
    required DeviceIdentity identity,
    required String displayName,
    required TransportKind kind,
    required String transportId,
    DateTime? at,
  });
  Future<void> forget(DeviceIdentity identity);
  Stream<List<KnownDevice>> watchAll();
}

/// App preferences (spec 7.3): a key/value store, one value per setting.
abstract interface class PreferencesRepository {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

/// Saved card dumps (spec 7.3).
///
/// Declared now so the seam exists; implemented in Phase 6.
abstract interface class SavedCardsRepository {
  Future<List<SavedCard>> all();
  Future<SavedCard?> byId(String id);
  Future<void> save(SavedCard card);
  Future<void> delete(String id);
  Stream<List<SavedCard>> watchAll();
}

/// Key dictionaries (spec 7.3).
///
/// Declared now so the seam exists; implemented in Phase 9.
abstract interface class DictionariesRepository {
  Future<List<KeyDictionary>> all();
  Future<void> save(KeyDictionary dictionary);
  Future<void> delete(String id);
  Stream<List<KeyDictionary>> watchAll();
}
