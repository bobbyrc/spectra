/// The Dictionaries feature's public API (spec 8.3): the key lists other
/// features read, and — from Task 9 — the picker they open to choose one.
///
/// Nothing else in the app may import `features/dictionaries/…` directly.
library;

export 'state/built_in_keys.dart'
    show builtInDictionary, builtInDictionaryId, defaultMifareKeys, isBuiltIn;
// `ImportOutcome` is deliberately *not* exported: `features/cards` declares
// its own type of that name, and a cards file that imports this barrel
// would then carry two `ImportOutcome`s.
export 'state/dictionaries_provider.dart' show dictionariesProvider;
