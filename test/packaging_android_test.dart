import 'dart:io';

import 'package:test/test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Android signing', () {
    late String gradle;
    setUpAll(() => gradle = _read('app/android/app/build.gradle.kts'));

    test('the flutter create signing TODO is gone', () {
      expect(gradle, isNot(contains('TODO: Add your own signing config')));
    });

    test('reads a keystore from key.properties or the environment', () {
      expect(gradle, contains('key.properties'));
      expect(gradle, contains('ANDROID_KEYSTORE_BASE64'));
      expect(gradle, contains('ANDROID_KEYSTORE_PASSWORD'));
      expect(gradle, contains('ANDROID_KEY_ALIAS'));
      expect(gradle, contains('ANDROID_KEY_PASSWORD'));
    });

    test('falls back to the debug keystore when there is none', () {
      expect(gradle, contains('signingConfigs.getByName("debug")'));
      expect(gradle, contains('release-unsigned'));
    });

    test('uses layout.buildDirectory, not the removed buildDir', () {
      expect(gradle, contains('layout.buildDirectory'));
      expect(gradle, isNot(contains('rootProject.buildDir')));
      expect(gradle, isNot(contains('project.buildDir')));
    });

    test('keystores and key.properties are git-ignored', () {
      final String ignore = _read('.gitignore');
      expect(ignore, contains('app/android/key.properties'));
      expect(ignore, contains('*.jks'));
      expect(ignore, contains('*.keystore'));
    });

    test('the example documents all four properties', () {
      final String example = _read('app/android/key.properties.example');
      for (final String key in const <String>[
        'storeFile',
        'storePassword',
        'keyAlias',
        'keyPassword',
      ]) {
        expect(example, contains(key));
      }
    });
  });
}
