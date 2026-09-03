// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spectra_database.dart';

// ignore_for_file: type=lint
class $SavedCardsTable extends SavedCards
    with TableInfo<$SavedCardsTable, SavedCardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagTypeMeta = const VerificationMeta(
    'tagType',
  );
  @override
  late final GeneratedColumn<String> tagType = GeneratedColumn<String>(
    'tag_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderMeta = const VerificationMeta('folder');
  @override
  late final GeneratedColumn<String> folder = GeneratedColumn<String>(
    'folder',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    tagType,
    bytes,
    folder,
    color,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedCardRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('tag_type')) {
      context.handle(
        _tagTypeMeta,
        tagType.isAcceptableOrUnknown(data['tag_type']!, _tagTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_tagTypeMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('folder')) {
      context.handle(
        _folderMeta,
        folder.isAcceptableOrUnknown(data['folder']!, _folderMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedCardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedCardRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      tagType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_type'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}bytes'],
      )!,
      folder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SavedCardsTable createAlias(String alias) {
    return $SavedCardsTable(attachedDatabase, alias);
  }
}

class SavedCardRow extends DataClass implements Insertable<SavedCardRow> {
  final String id;
  final String name;
  final String tagType;
  final Uint8List bytes;
  final String? folder;
  final int? color;
  final DateTime updatedAt;
  const SavedCardRow({
    required this.id,
    required this.name,
    required this.tagType,
    required this.bytes,
    this.folder,
    this.color,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['tag_type'] = Variable<String>(tagType);
    map['bytes'] = Variable<Uint8List>(bytes);
    if (!nullToAbsent || folder != null) {
      map['folder'] = Variable<String>(folder);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<int>(color);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SavedCardsCompanion toCompanion(bool nullToAbsent) {
    return SavedCardsCompanion(
      id: Value(id),
      name: Value(name),
      tagType: Value(tagType),
      bytes: Value(bytes),
      folder: folder == null && nullToAbsent
          ? const Value.absent()
          : Value(folder),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      updatedAt: Value(updatedAt),
    );
  }

  factory SavedCardRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedCardRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      tagType: serializer.fromJson<String>(json['tagType']),
      bytes: serializer.fromJson<Uint8List>(json['bytes']),
      folder: serializer.fromJson<String?>(json['folder']),
      color: serializer.fromJson<int?>(json['color']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'tagType': serializer.toJson<String>(tagType),
      'bytes': serializer.toJson<Uint8List>(bytes),
      'folder': serializer.toJson<String?>(folder),
      'color': serializer.toJson<int?>(color),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SavedCardRow copyWith({
    String? id,
    String? name,
    String? tagType,
    Uint8List? bytes,
    Value<String?> folder = const Value.absent(),
    Value<int?> color = const Value.absent(),
    DateTime? updatedAt,
  }) => SavedCardRow(
    id: id ?? this.id,
    name: name ?? this.name,
    tagType: tagType ?? this.tagType,
    bytes: bytes ?? this.bytes,
    folder: folder.present ? folder.value : this.folder,
    color: color.present ? color.value : this.color,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SavedCardRow copyWithCompanion(SavedCardsCompanion data) {
    return SavedCardRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      tagType: data.tagType.present ? data.tagType.value : this.tagType,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      folder: data.folder.present ? data.folder.value : this.folder,
      color: data.color.present ? data.color.value : this.color,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedCardRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('tagType: $tagType, ')
          ..write('bytes: $bytes, ')
          ..write('folder: $folder, ')
          ..write('color: $color, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    tagType,
    $driftBlobEquality.hash(bytes),
    folder,
    color,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedCardRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.tagType == this.tagType &&
          $driftBlobEquality.equals(other.bytes, this.bytes) &&
          other.folder == this.folder &&
          other.color == this.color &&
          other.updatedAt == this.updatedAt);
}

class SavedCardsCompanion extends UpdateCompanion<SavedCardRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> tagType;
  final Value<Uint8List> bytes;
  final Value<String?> folder;
  final Value<int?> color;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SavedCardsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.tagType = const Value.absent(),
    this.bytes = const Value.absent(),
    this.folder = const Value.absent(),
    this.color = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedCardsCompanion.insert({
    required String id,
    required String name,
    required String tagType,
    required Uint8List bytes,
    this.folder = const Value.absent(),
    this.color = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       tagType = Value(tagType),
       bytes = Value(bytes),
       updatedAt = Value(updatedAt);
  static Insertable<SavedCardRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? tagType,
    Expression<Uint8List>? bytes,
    Expression<String>? folder,
    Expression<int>? color,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (tagType != null) 'tag_type': tagType,
      if (bytes != null) 'bytes': bytes,
      if (folder != null) 'folder': folder,
      if (color != null) 'color': color,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedCardsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? tagType,
    Value<Uint8List>? bytes,
    Value<String?>? folder,
    Value<int?>? color,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SavedCardsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      tagType: tagType ?? this.tagType,
      bytes: bytes ?? this.bytes,
      folder: folder ?? this.folder,
      color: color ?? this.color,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (tagType.present) {
      map['tag_type'] = Variable<String>(tagType.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    if (folder.present) {
      map['folder'] = Variable<String>(folder.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedCardsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('tagType: $tagType, ')
          ..write('bytes: $bytes, ')
          ..write('folder: $folder, ')
          ..write('color: $color, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KeyDictionariesTable extends KeyDictionaries
    with TableInfo<$KeyDictionariesTable, KeyDictionaryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KeyDictionariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keysMeta = const VerificationMeta('keys');
  @override
  late final GeneratedColumn<String> keys = GeneratedColumn<String>(
    'keys',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, keys, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'key_dictionaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<KeyDictionaryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('keys')) {
      context.handle(
        _keysMeta,
        keys.isAcceptableOrUnknown(data['keys']!, _keysMeta),
      );
    } else if (isInserting) {
      context.missing(_keysMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  KeyDictionaryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KeyDictionaryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      keys: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}keys'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $KeyDictionariesTable createAlias(String alias) {
    return $KeyDictionariesTable(attachedDatabase, alias);
  }
}

class KeyDictionaryRow extends DataClass
    implements Insertable<KeyDictionaryRow> {
  final String id;
  final String name;
  final String keys;
  final DateTime updatedAt;
  const KeyDictionaryRow({
    required this.id,
    required this.name,
    required this.keys,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['keys'] = Variable<String>(keys);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  KeyDictionariesCompanion toCompanion(bool nullToAbsent) {
    return KeyDictionariesCompanion(
      id: Value(id),
      name: Value(name),
      keys: Value(keys),
      updatedAt: Value(updatedAt),
    );
  }

  factory KeyDictionaryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KeyDictionaryRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      keys: serializer.fromJson<String>(json['keys']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'keys': serializer.toJson<String>(keys),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  KeyDictionaryRow copyWith({
    String? id,
    String? name,
    String? keys,
    DateTime? updatedAt,
  }) => KeyDictionaryRow(
    id: id ?? this.id,
    name: name ?? this.name,
    keys: keys ?? this.keys,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  KeyDictionaryRow copyWithCompanion(KeyDictionariesCompanion data) {
    return KeyDictionaryRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      keys: data.keys.present ? data.keys.value : this.keys,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KeyDictionaryRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('keys: $keys, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, keys, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KeyDictionaryRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.keys == this.keys &&
          other.updatedAt == this.updatedAt);
}

class KeyDictionariesCompanion extends UpdateCompanion<KeyDictionaryRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> keys;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const KeyDictionariesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.keys = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KeyDictionariesCompanion.insert({
    required String id,
    required String name,
    required String keys,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       keys = Value(keys),
       updatedAt = Value(updatedAt);
  static Insertable<KeyDictionaryRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? keys,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (keys != null) 'keys': keys,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KeyDictionariesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? keys,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return KeyDictionariesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      keys: keys ?? this.keys,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (keys.present) {
      map['keys'] = Variable<String>(keys.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KeyDictionariesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('keys: $keys, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KnownDevicesTable extends KnownDevices
    with TableInfo<$KnownDevicesTable, KnownDeviceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KnownDevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _identityMeta = const VerificationMeta(
    'identity',
  );
  @override
  late final GeneratedColumn<String> identity = GeneratedColumn<String>(
    'identity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transportsMeta = const VerificationMeta(
    'transports',
  );
  @override
  late final GeneratedColumn<String> transports = GeneratedColumn<String>(
    'transports',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeen = GeneratedColumn<DateTime>(
    'last_seen',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    identity,
    displayName,
    transports,
    lastSeen,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'known_devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<KnownDeviceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('identity')) {
      context.handle(
        _identityMeta,
        identity.isAcceptableOrUnknown(data['identity']!, _identityMeta),
      );
    } else if (isInserting) {
      context.missing(_identityMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('transports')) {
      context.handle(
        _transportsMeta,
        transports.isAcceptableOrUnknown(data['transports']!, _transportsMeta),
      );
    } else if (isInserting) {
      context.missing(_transportsMeta);
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    } else if (isInserting) {
      context.missing(_lastSeenMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {identity};
  @override
  KnownDeviceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KnownDeviceRow(
      identity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}identity'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      transports: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transports'],
      )!,
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen'],
      )!,
    );
  }

  @override
  $KnownDevicesTable createAlias(String alias) {
    return $KnownDevicesTable(attachedDatabase, alias);
  }
}

class KnownDeviceRow extends DataClass implements Insertable<KnownDeviceRow> {
  final String identity;
  final String displayName;
  final String transports;
  final DateTime lastSeen;
  const KnownDeviceRow({
    required this.identity,
    required this.displayName,
    required this.transports,
    required this.lastSeen,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['identity'] = Variable<String>(identity);
    map['display_name'] = Variable<String>(displayName);
    map['transports'] = Variable<String>(transports);
    map['last_seen'] = Variable<DateTime>(lastSeen);
    return map;
  }

  KnownDevicesCompanion toCompanion(bool nullToAbsent) {
    return KnownDevicesCompanion(
      identity: Value(identity),
      displayName: Value(displayName),
      transports: Value(transports),
      lastSeen: Value(lastSeen),
    );
  }

  factory KnownDeviceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KnownDeviceRow(
      identity: serializer.fromJson<String>(json['identity']),
      displayName: serializer.fromJson<String>(json['displayName']),
      transports: serializer.fromJson<String>(json['transports']),
      lastSeen: serializer.fromJson<DateTime>(json['lastSeen']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'identity': serializer.toJson<String>(identity),
      'displayName': serializer.toJson<String>(displayName),
      'transports': serializer.toJson<String>(transports),
      'lastSeen': serializer.toJson<DateTime>(lastSeen),
    };
  }

  KnownDeviceRow copyWith({
    String? identity,
    String? displayName,
    String? transports,
    DateTime? lastSeen,
  }) => KnownDeviceRow(
    identity: identity ?? this.identity,
    displayName: displayName ?? this.displayName,
    transports: transports ?? this.transports,
    lastSeen: lastSeen ?? this.lastSeen,
  );
  KnownDeviceRow copyWithCompanion(KnownDevicesCompanion data) {
    return KnownDeviceRow(
      identity: data.identity.present ? data.identity.value : this.identity,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      transports: data.transports.present
          ? data.transports.value
          : this.transports,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KnownDeviceRow(')
          ..write('identity: $identity, ')
          ..write('displayName: $displayName, ')
          ..write('transports: $transports, ')
          ..write('lastSeen: $lastSeen')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(identity, displayName, transports, lastSeen);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KnownDeviceRow &&
          other.identity == this.identity &&
          other.displayName == this.displayName &&
          other.transports == this.transports &&
          other.lastSeen == this.lastSeen);
}

class KnownDevicesCompanion extends UpdateCompanion<KnownDeviceRow> {
  final Value<String> identity;
  final Value<String> displayName;
  final Value<String> transports;
  final Value<DateTime> lastSeen;
  final Value<int> rowid;
  const KnownDevicesCompanion({
    this.identity = const Value.absent(),
    this.displayName = const Value.absent(),
    this.transports = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KnownDevicesCompanion.insert({
    required String identity,
    required String displayName,
    required String transports,
    required DateTime lastSeen,
    this.rowid = const Value.absent(),
  }) : identity = Value(identity),
       displayName = Value(displayName),
       transports = Value(transports),
       lastSeen = Value(lastSeen);
  static Insertable<KnownDeviceRow> custom({
    Expression<String>? identity,
    Expression<String>? displayName,
    Expression<String>? transports,
    Expression<DateTime>? lastSeen,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (identity != null) 'identity': identity,
      if (displayName != null) 'display_name': displayName,
      if (transports != null) 'transports': transports,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KnownDevicesCompanion copyWith({
    Value<String>? identity,
    Value<String>? displayName,
    Value<String>? transports,
    Value<DateTime>? lastSeen,
    Value<int>? rowid,
  }) {
    return KnownDevicesCompanion(
      identity: identity ?? this.identity,
      displayName: displayName ?? this.displayName,
      transports: transports ?? this.transports,
      lastSeen: lastSeen ?? this.lastSeen,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (identity.present) {
      map['identity'] = Variable<String>(identity.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (transports.present) {
      map['transports'] = Variable<String>(transports.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<DateTime>(lastSeen.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KnownDevicesCompanion(')
          ..write('identity: $identity, ')
          ..write('displayName: $displayName, ')
          ..write('transports: $transports, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppPreferencesTable extends AppPreferences
    with TableInfo<$AppPreferencesTable, AppPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppPreference(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppPreferencesTable createAlias(String alias) {
    return $AppPreferencesTable(attachedDatabase, alias);
  }
}

class AppPreference extends DataClass implements Insertable<AppPreference> {
  final String key;
  final String value;
  const AppPreference({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppPreferencesCompanion toCompanion(bool nullToAbsent) {
    return AppPreferencesCompanion(key: Value(key), value: Value(value));
  }

  factory AppPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppPreference(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppPreference copyWith({String? key, String? value}) =>
      AppPreference(key: key ?? this.key, value: value ?? this.value);
  AppPreference copyWithCompanion(AppPreferencesCompanion data) {
    return AppPreference(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppPreference(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppPreference &&
          other.key == this.key &&
          other.value == this.value);
}

class AppPreferencesCompanion extends UpdateCompanion<AppPreference> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppPreferencesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppPreferencesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppPreference> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppPreferencesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppPreferencesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppPreferencesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$SpectraDatabase extends GeneratedDatabase {
  _$SpectraDatabase(QueryExecutor e) : super(e);
  $SpectraDatabaseManager get managers => $SpectraDatabaseManager(this);
  late final $SavedCardsTable savedCards = $SavedCardsTable(this);
  late final $KeyDictionariesTable keyDictionaries = $KeyDictionariesTable(
    this,
  );
  late final $KnownDevicesTable knownDevices = $KnownDevicesTable(this);
  late final $AppPreferencesTable appPreferences = $AppPreferencesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    savedCards,
    keyDictionaries,
    knownDevices,
    appPreferences,
  ];
}

typedef $$SavedCardsTableCreateCompanionBuilder = SavedCardsCompanion Function({
  required String id,
  required String name,
  required String tagType,
  required Uint8List bytes,
  Value<String?> folder,
  Value<int?> color,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$SavedCardsTableUpdateCompanionBuilder = SavedCardsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> tagType,
  Value<Uint8List> bytes,
  Value<String?> folder,
  Value<int?> color,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$SavedCardsTableFilterComposer
    extends Composer<_$SpectraDatabase, $SavedCardsTable> {
  $$SavedCardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagType => $composableBuilder(
    column: $table.tagType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folder => $composableBuilder(
    column: $table.folder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SavedCardsTableOrderingComposer
    extends Composer<_$SpectraDatabase, $SavedCardsTable> {
  $$SavedCardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagType => $composableBuilder(
    column: $table.tagType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folder => $composableBuilder(
    column: $table.folder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedCardsTableAnnotationComposer
    extends Composer<_$SpectraDatabase, $SavedCardsTable> {
  $$SavedCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get tagType =>
      $composableBuilder(column: $table.tagType, builder: (column) => column);

  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get folder =>
      $composableBuilder(column: $table.folder, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SavedCardsTableTableManager
    extends
        RootTableManager<
          _$SpectraDatabase,
          $SavedCardsTable,
          SavedCardRow,
          $$SavedCardsTableFilterComposer,
          $$SavedCardsTableOrderingComposer,
          $$SavedCardsTableAnnotationComposer,
          $$SavedCardsTableCreateCompanionBuilder,
          $$SavedCardsTableUpdateCompanionBuilder,
          (
            SavedCardRow,
            BaseReferences<_$SpectraDatabase, $SavedCardsTable, SavedCardRow>,
          ),
          SavedCardRow,
          PrefetchHooks Function()
        > {
  $$SavedCardsTableTableManager(_$SpectraDatabase db, $SavedCardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> tagType = const Value.absent(),
                Value<Uint8List> bytes = const Value.absent(),
                Value<String?> folder = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedCardsCompanion(
                id: id,
                name: name,
                tagType: tagType,
                bytes: bytes,
                folder: folder,
                color: color,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String tagType,
                required Uint8List bytes,
                Value<String?> folder = const Value.absent(),
                Value<int?> color = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SavedCardsCompanion.insert(
                id: id,
                name: name,
                tagType: tagType,
                bytes: bytes,
                folder: folder,
                color: color,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SavedCardsTable, SavedCardRow>(table),
                  BaseReferences<
                    _$SpectraDatabase,
                    $SavedCardsTable,
                    SavedCardRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SavedCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$SpectraDatabase,
      $SavedCardsTable,
      SavedCardRow,
      $$SavedCardsTableFilterComposer,
      $$SavedCardsTableOrderingComposer,
      $$SavedCardsTableAnnotationComposer,
      $$SavedCardsTableCreateCompanionBuilder,
      $$SavedCardsTableUpdateCompanionBuilder,
      (
        SavedCardRow,
        BaseReferences<_$SpectraDatabase, $SavedCardsTable, SavedCardRow>,
      ),
      SavedCardRow,
      PrefetchHooks Function()
    >;
typedef $$KeyDictionariesTableCreateCompanionBuilder =
    KeyDictionariesCompanion Function({
      required String id,
      required String name,
      required String keys,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$KeyDictionariesTableUpdateCompanionBuilder =
    KeyDictionariesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> keys,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$KeyDictionariesTableFilterComposer
    extends Composer<_$SpectraDatabase, $KeyDictionariesTable> {
  $$KeyDictionariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keys => $composableBuilder(
    column: $table.keys,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KeyDictionariesTableOrderingComposer
    extends Composer<_$SpectraDatabase, $KeyDictionariesTable> {
  $$KeyDictionariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keys => $composableBuilder(
    column: $table.keys,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KeyDictionariesTableAnnotationComposer
    extends Composer<_$SpectraDatabase, $KeyDictionariesTable> {
  $$KeyDictionariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get keys =>
      $composableBuilder(column: $table.keys, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$KeyDictionariesTableTableManager
    extends
        RootTableManager<
          _$SpectraDatabase,
          $KeyDictionariesTable,
          KeyDictionaryRow,
          $$KeyDictionariesTableFilterComposer,
          $$KeyDictionariesTableOrderingComposer,
          $$KeyDictionariesTableAnnotationComposer,
          $$KeyDictionariesTableCreateCompanionBuilder,
          $$KeyDictionariesTableUpdateCompanionBuilder,
          (
            KeyDictionaryRow,
            BaseReferences<
              _$SpectraDatabase,
              $KeyDictionariesTable,
              KeyDictionaryRow
            >,
          ),
          KeyDictionaryRow,
          PrefetchHooks Function()
        > {
  $$KeyDictionariesTableTableManager(
    _$SpectraDatabase db,
    $KeyDictionariesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KeyDictionariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KeyDictionariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KeyDictionariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> keys = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KeyDictionariesCompanion(
                id: id,
                name: name,
                keys: keys,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String keys,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => KeyDictionariesCompanion.insert(
                id: id,
                name: name,
                keys: keys,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KeyDictionariesTable, KeyDictionaryRow>(table),
                  BaseReferences<
                    _$SpectraDatabase,
                    $KeyDictionariesTable,
                    KeyDictionaryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KeyDictionariesTableProcessedTableManager =
    ProcessedTableManager<
      _$SpectraDatabase,
      $KeyDictionariesTable,
      KeyDictionaryRow,
      $$KeyDictionariesTableFilterComposer,
      $$KeyDictionariesTableOrderingComposer,
      $$KeyDictionariesTableAnnotationComposer,
      $$KeyDictionariesTableCreateCompanionBuilder,
      $$KeyDictionariesTableUpdateCompanionBuilder,
      (
        KeyDictionaryRow,
        BaseReferences<
          _$SpectraDatabase,
          $KeyDictionariesTable,
          KeyDictionaryRow
        >,
      ),
      KeyDictionaryRow,
      PrefetchHooks Function()
    >;
typedef $$KnownDevicesTableCreateCompanionBuilder =
    KnownDevicesCompanion Function({
      required String identity,
      required String displayName,
      required String transports,
      required DateTime lastSeen,
      Value<int> rowid,
    });
typedef $$KnownDevicesTableUpdateCompanionBuilder =
    KnownDevicesCompanion Function({
      Value<String> identity,
      Value<String> displayName,
      Value<String> transports,
      Value<DateTime> lastSeen,
      Value<int> rowid,
    });

class $$KnownDevicesTableFilterComposer
    extends Composer<_$SpectraDatabase, $KnownDevicesTable> {
  $$KnownDevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get identity => $composableBuilder(
    column: $table.identity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transports => $composableBuilder(
    column: $table.transports,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KnownDevicesTableOrderingComposer
    extends Composer<_$SpectraDatabase, $KnownDevicesTable> {
  $$KnownDevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get identity => $composableBuilder(
    column: $table.identity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transports => $composableBuilder(
    column: $table.transports,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KnownDevicesTableAnnotationComposer
    extends Composer<_$SpectraDatabase, $KnownDevicesTable> {
  $$KnownDevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get identity =>
      $composableBuilder(column: $table.identity, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transports => $composableBuilder(
    column: $table.transports,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);
}

class $$KnownDevicesTableTableManager
    extends
        RootTableManager<
          _$SpectraDatabase,
          $KnownDevicesTable,
          KnownDeviceRow,
          $$KnownDevicesTableFilterComposer,
          $$KnownDevicesTableOrderingComposer,
          $$KnownDevicesTableAnnotationComposer,
          $$KnownDevicesTableCreateCompanionBuilder,
          $$KnownDevicesTableUpdateCompanionBuilder,
          (
            KnownDeviceRow,
            BaseReferences<
              _$SpectraDatabase,
              $KnownDevicesTable,
              KnownDeviceRow
            >,
          ),
          KnownDeviceRow,
          PrefetchHooks Function()
        > {
  $$KnownDevicesTableTableManager(
    _$SpectraDatabase db,
    $KnownDevicesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KnownDevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KnownDevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KnownDevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> identity = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> transports = const Value.absent(),
                Value<DateTime> lastSeen = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KnownDevicesCompanion(
                identity: identity,
                displayName: displayName,
                transports: transports,
                lastSeen: lastSeen,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String identity,
                required String displayName,
                required String transports,
                required DateTime lastSeen,
                Value<int> rowid = const Value.absent(),
              }) => KnownDevicesCompanion.insert(
                identity: identity,
                displayName: displayName,
                transports: transports,
                lastSeen: lastSeen,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KnownDevicesTable, KnownDeviceRow>(table),
                  BaseReferences<
                    _$SpectraDatabase,
                    $KnownDevicesTable,
                    KnownDeviceRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KnownDevicesTableProcessedTableManager =
    ProcessedTableManager<
      _$SpectraDatabase,
      $KnownDevicesTable,
      KnownDeviceRow,
      $$KnownDevicesTableFilterComposer,
      $$KnownDevicesTableOrderingComposer,
      $$KnownDevicesTableAnnotationComposer,
      $$KnownDevicesTableCreateCompanionBuilder,
      $$KnownDevicesTableUpdateCompanionBuilder,
      (
        KnownDeviceRow,
        BaseReferences<_$SpectraDatabase, $KnownDevicesTable, KnownDeviceRow>,
      ),
      KnownDeviceRow,
      PrefetchHooks Function()
    >;
typedef $$AppPreferencesTableCreateCompanionBuilder =
    AppPreferencesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppPreferencesTableUpdateCompanionBuilder =
    AppPreferencesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppPreferencesTableFilterComposer
    extends Composer<_$SpectraDatabase, $AppPreferencesTable> {
  $$AppPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppPreferencesTableOrderingComposer
    extends Composer<_$SpectraDatabase, $AppPreferencesTable> {
  $$AppPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppPreferencesTableAnnotationComposer
    extends Composer<_$SpectraDatabase, $AppPreferencesTable> {
  $$AppPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppPreferencesTableTableManager
    extends
        RootTableManager<
          _$SpectraDatabase,
          $AppPreferencesTable,
          AppPreference,
          $$AppPreferencesTableFilterComposer,
          $$AppPreferencesTableOrderingComposer,
          $$AppPreferencesTableAnnotationComposer,
          $$AppPreferencesTableCreateCompanionBuilder,
          $$AppPreferencesTableUpdateCompanionBuilder,
          (
            AppPreference,
            BaseReferences<
              _$SpectraDatabase,
              $AppPreferencesTable,
              AppPreference
            >,
          ),
          AppPreference,
          PrefetchHooks Function()
        > {
  $$AppPreferencesTableTableManager(
    _$SpectraDatabase db,
    $AppPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppPreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppPreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AppPreferencesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppPreferencesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppPreferencesTable, AppPreference>(table),
                  BaseReferences<
                    _$SpectraDatabase,
                    $AppPreferencesTable,
                    AppPreference
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$SpectraDatabase,
      $AppPreferencesTable,
      AppPreference,
      $$AppPreferencesTableFilterComposer,
      $$AppPreferencesTableOrderingComposer,
      $$AppPreferencesTableAnnotationComposer,
      $$AppPreferencesTableCreateCompanionBuilder,
      $$AppPreferencesTableUpdateCompanionBuilder,
      (
        AppPreference,
        BaseReferences<_$SpectraDatabase, $AppPreferencesTable, AppPreference>,
      ),
      AppPreference,
      PrefetchHooks Function()
    >;

class $SpectraDatabaseManager {
  final _$SpectraDatabase _db;
  $SpectraDatabaseManager(this._db);
  $$SavedCardsTableTableManager get savedCards =>
      $$SavedCardsTableTableManager(_db, _db.savedCards);
  $$KeyDictionariesTableTableManager get keyDictionaries =>
      $$KeyDictionariesTableTableManager(_db, _db.keyDictionaries);
  $$KnownDevicesTableTableManager get knownDevices =>
      $$KnownDevicesTableTableManager(_db, _db.knownDevices);
  $$AppPreferencesTableTableManager get appPreferences =>
      $$AppPreferencesTableTableManager(_db, _db.appPreferences);
}
