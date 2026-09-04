import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/data/database/spectra_database.dart';

import '../generated_migrations/schema.dart';

/// Spec 7.3: "Drift schema migrations with generated schema-verification
/// tests from the first table." Version 1 is the baseline, so this asserts
/// that a fresh database matches the exported v1 schema exactly. Every later
/// phase that adds a table exports a new version and adds a step here.
void main() {
  test('a fresh database matches the exported v1 schema', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.schemaAt(1);
    final db = SpectraDatabase(connection.newConnection());
    await verifier.migrateAndValidate(db, 1);
    await db.close();
  });
}
