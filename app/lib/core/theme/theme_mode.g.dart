// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_mode.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's theme choice (spec 7.7 step 7), persisted like every other app
/// preference. The same `PreferencesRepository`-backed keepAlive shape
/// `core/flags/feature_flags.dart` uses: an async controller, plus a plain
/// value provider so a widget above `Localizations` — `SpectraRoot` — can
/// read it synchronously.

@ProviderFor(ThemeModeController)
final themeModeControllerProvider = ThemeModeControllerProvider._();

/// The app's theme choice (spec 7.7 step 7), persisted like every other app
/// preference. The same `PreferencesRepository`-backed keepAlive shape
/// `core/flags/feature_flags.dart` uses: an async controller, plus a plain
/// value provider so a widget above `Localizations` — `SpectraRoot` — can
/// read it synchronously.
final class ThemeModeControllerProvider
    extends $AsyncNotifierProvider<ThemeModeController, ThemeMode> {
  /// The app's theme choice (spec 7.7 step 7), persisted like every other app
  /// preference. The same `PreferencesRepository`-backed keepAlive shape
  /// `core/flags/feature_flags.dart` uses: an async controller, plus a plain
  /// value provider so a widget above `Localizations` — `SpectraRoot` — can
  /// read it synchronously.
  ThemeModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeControllerHash();

  @$internal
  @override
  ThemeModeController create() => ThemeModeController();
}

String _$themeModeControllerHash() =>
    r'7d97f4a3bc3afea57bf5039b6d8bfd4d7cdde613';

/// The app's theme choice (spec 7.7 step 7), persisted like every other app
/// preference. The same `PreferencesRepository`-backed keepAlive shape
/// `core/flags/feature_flags.dart` uses: an async controller, plus a plain
/// value provider so a widget above `Localizations` — `SpectraRoot` — can
/// read it synchronously.

abstract class _$ThemeModeController extends $AsyncNotifier<ThemeMode> {
  FutureOr<ThemeMode> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ThemeMode>, ThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ThemeMode>, ThemeMode>,
              AsyncValue<ThemeMode>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The theme as a plain value: the system theme until the stored one loads,
/// which is the safe direction (it is what the platform already shows).

@ProviderFor(themeMode)
final themeModeProvider = ThemeModeProvider._();

/// The theme as a plain value: the system theme until the stored one loads,
/// which is the safe direction (it is what the platform already shows).

final class ThemeModeProvider
    extends $FunctionalProvider<ThemeMode, ThemeMode, ThemeMode>
    with $Provider<ThemeMode> {
  /// The theme as a plain value: the system theme until the stored one loads,
  /// which is the safe direction (it is what the platform already shows).
  ThemeModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeHash();

  @$internal
  @override
  $ProviderElement<ThemeMode> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ThemeMode create(Ref ref) {
    return themeMode(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeMode>(value),
    );
  }
}

String _$themeModeHash() => r'30f569f942e418b4559f395ec26c144397501b14';
