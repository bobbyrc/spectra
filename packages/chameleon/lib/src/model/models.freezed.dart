// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FirmwareVersion {

 int get major; int get minor;
/// Create a copy of FirmwareVersion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FirmwareVersionCopyWith<FirmwareVersion> get copyWith => _$FirmwareVersionCopyWithImpl<FirmwareVersion>(this as FirmwareVersion, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as FirmwareVersion;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FirmwareVersion&&(identical(other.major, _this.major) || other.major == _this.major)&&(identical(other.minor, _this.minor) || other.minor == _this.minor));
}


@override
int get hashCode {
  final _this = this as FirmwareVersion;
  return Object.hash(runtimeType,_this.major,_this.minor);
}

@override
String toString() {
  final _this = this as FirmwareVersion;
  return 'FirmwareVersion(major: ${_this.major}, minor: ${_this.minor})';
}


}

/// @nodoc
abstract mixin class $FirmwareVersionCopyWith<$Res>  {
  factory $FirmwareVersionCopyWith(FirmwareVersion value, $Res Function(FirmwareVersion) _then) = _$FirmwareVersionCopyWithImpl;
@useResult
$Res call({
 int major, int minor
});




}
/// @nodoc
class _$FirmwareVersionCopyWithImpl<$Res>
    implements $FirmwareVersionCopyWith<$Res> {
  _$FirmwareVersionCopyWithImpl(this._self, this._then);

  final FirmwareVersion _self;
  final $Res Function(FirmwareVersion) _then;

/// Create a copy of FirmwareVersion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? major = null,Object? minor = null,}) {
  return _then(FirmwareVersion(
major: null == major ? _self.major : major // ignore: cast_nullable_to_non_nullable
as int,minor: null == minor ? _self.minor : minor // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [FirmwareVersion].
extension FirmwareVersionPatterns on FirmwareVersion {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FirmwareVersion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FirmwareVersion() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FirmwareVersion value)  $default,){
final _that = this;
switch (_that) {
case _FirmwareVersion():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FirmwareVersion value)?  $default,){
final _that = this;
switch (_that) {
case _FirmwareVersion() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int major,  int minor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FirmwareVersion() when $default != null:
return $default(_that.major,_that.minor);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int major,  int minor)  $default,) {final _that = this;
switch (_that) {
case _FirmwareVersion():
return $default(_that.major,_that.minor);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int major,  int minor)?  $default,) {final _that = this;
switch (_that) {
case _FirmwareVersion() when $default != null:
return $default(_that.major,_that.minor);case _:
  return null;

}
}

}

/// @nodoc


class _FirmwareVersion extends FirmwareVersion {
  const _FirmwareVersion({required this.major, required this.minor}): super._();
  

@override final  int major;
@override final  int minor;

/// Create a copy of FirmwareVersion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FirmwareVersionCopyWith<_FirmwareVersion> get copyWith => __$FirmwareVersionCopyWithImpl<_FirmwareVersion>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FirmwareVersion&&(identical(other.major, major) || other.major == major)&&(identical(other.minor, minor) || other.minor == minor));
}


@override
int get hashCode {
    return Object.hash(runtimeType,major,minor);
}

@override
String toString() {
    return 'FirmwareVersion(major: $major, minor: $minor)';
}


}

/// @nodoc
abstract mixin class _$FirmwareVersionCopyWith<$Res> implements $FirmwareVersionCopyWith<$Res> {
  factory _$FirmwareVersionCopyWith(_FirmwareVersion value, $Res Function(_FirmwareVersion) _then) = __$FirmwareVersionCopyWithImpl;
@override @useResult
$Res call({
 int major, int minor
});




}
/// @nodoc
class __$FirmwareVersionCopyWithImpl<$Res>
    implements _$FirmwareVersionCopyWith<$Res> {
  __$FirmwareVersionCopyWithImpl(this._self, this._then);

  final _FirmwareVersion _self;
  final $Res Function(_FirmwareVersion) _then;

/// Create a copy of FirmwareVersion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? major = null,Object? minor = null,}) {
  return _then(_FirmwareVersion(
major: null == major ? _self.major : major // ignore: cast_nullable_to_non_nullable
as int,minor: null == minor ? _self.minor : minor // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$Capabilities {

 Set<int> get commandIds;
/// Create a copy of Capabilities
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CapabilitiesCopyWith<Capabilities> get copyWith => _$CapabilitiesCopyWithImpl<Capabilities>(this as Capabilities, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Capabilities;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Capabilities&&const DeepCollectionEquality().equals(other.commandIds, _this.commandIds));
}


@override
int get hashCode {
  final _this = this as Capabilities;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.commandIds));
}

@override
String toString() {
  final _this = this as Capabilities;
  return 'Capabilities(commandIds: ${_this.commandIds})';
}


}

/// @nodoc
abstract mixin class $CapabilitiesCopyWith<$Res>  {
  factory $CapabilitiesCopyWith(Capabilities value, $Res Function(Capabilities) _then) = _$CapabilitiesCopyWithImpl;
@useResult
$Res call({
 Set<int> commandIds
});




}
/// @nodoc
class _$CapabilitiesCopyWithImpl<$Res>
    implements $CapabilitiesCopyWith<$Res> {
  _$CapabilitiesCopyWithImpl(this._self, this._then);

  final Capabilities _self;
  final $Res Function(Capabilities) _then;

/// Create a copy of Capabilities
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? commandIds = null,}) {
  return _then(Capabilities(
null == commandIds ? _self.commandIds : commandIds // ignore: cast_nullable_to_non_nullable
as Set<int>,
  ));
}

}


/// Adds pattern-matching-related methods to [Capabilities].
extension CapabilitiesPatterns on Capabilities {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Capabilities value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Capabilities() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Capabilities value)  $default,){
final _that = this;
switch (_that) {
case _Capabilities():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Capabilities value)?  $default,){
final _that = this;
switch (_that) {
case _Capabilities() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Set<int> commandIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Capabilities() when $default != null:
return $default(_that.commandIds);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Set<int> commandIds)  $default,) {final _that = this;
switch (_that) {
case _Capabilities():
return $default(_that.commandIds);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Set<int> commandIds)?  $default,) {final _that = this;
switch (_that) {
case _Capabilities() when $default != null:
return $default(_that.commandIds);case _:
  return null;

}
}

}

/// @nodoc


class _Capabilities extends Capabilities {
  const _Capabilities( Set<int> commandIds): _commandIds = commandIds,super._();
  

 final  Set<int> _commandIds;
@override Set<int> get commandIds {
  if (_commandIds is EqualUnmodifiableSetView) return _commandIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_commandIds);
}


/// Create a copy of Capabilities
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CapabilitiesCopyWith<_Capabilities> get copyWith => __$CapabilitiesCopyWithImpl<_Capabilities>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Capabilities&&const DeepCollectionEquality().equals(other.commandIds, _commandIds));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_commandIds));
}

@override
String toString() {
    return 'Capabilities(commandIds: $commandIds)';
}


}

/// @nodoc
abstract mixin class _$CapabilitiesCopyWith<$Res> implements $CapabilitiesCopyWith<$Res> {
  factory _$CapabilitiesCopyWith(_Capabilities value, $Res Function(_Capabilities) _then) = __$CapabilitiesCopyWithImpl;
@override @useResult
$Res call({
 Set<int> commandIds
});




}
/// @nodoc
class __$CapabilitiesCopyWithImpl<$Res>
    implements _$CapabilitiesCopyWith<$Res> {
  __$CapabilitiesCopyWithImpl(this._self, this._then);

  final _Capabilities _self;
  final $Res Function(_Capabilities) _then;

/// Create a copy of Capabilities
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? commandIds = null,}) {
  return _then(_Capabilities(
null == commandIds ? _self._commandIds : commandIds // ignore: cast_nullable_to_non_nullable
as Set<int>,
  ));
}


}

/// @nodoc
mixin _$DeviceIdentity {

 String get chipId;
/// Create a copy of DeviceIdentity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceIdentityCopyWith<DeviceIdentity> get copyWith => _$DeviceIdentityCopyWithImpl<DeviceIdentity>(this as DeviceIdentity, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as DeviceIdentity;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceIdentity&&(identical(other.chipId, _this.chipId) || other.chipId == _this.chipId));
}


@override
int get hashCode {
  final _this = this as DeviceIdentity;
  return Object.hash(runtimeType,_this.chipId);
}

@override
String toString() {
  final _this = this as DeviceIdentity;
  return 'DeviceIdentity(chipId: ${_this.chipId})';
}


}

/// @nodoc
abstract mixin class $DeviceIdentityCopyWith<$Res>  {
  factory $DeviceIdentityCopyWith(DeviceIdentity value, $Res Function(DeviceIdentity) _then) = _$DeviceIdentityCopyWithImpl;
@useResult
$Res call({
 String chipId
});




}
/// @nodoc
class _$DeviceIdentityCopyWithImpl<$Res>
    implements $DeviceIdentityCopyWith<$Res> {
  _$DeviceIdentityCopyWithImpl(this._self, this._then);

  final DeviceIdentity _self;
  final $Res Function(DeviceIdentity) _then;

/// Create a copy of DeviceIdentity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chipId = null,}) {
  return _then(DeviceIdentity(
null == chipId ? _self.chipId : chipId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DeviceIdentity].
extension DeviceIdentityPatterns on DeviceIdentity {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceIdentity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceIdentity() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceIdentity value)  $default,){
final _that = this;
switch (_that) {
case _DeviceIdentity():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceIdentity value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceIdentity() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String chipId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceIdentity() when $default != null:
return $default(_that.chipId);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String chipId)  $default,) {final _that = this;
switch (_that) {
case _DeviceIdentity():
return $default(_that.chipId);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String chipId)?  $default,) {final _that = this;
switch (_that) {
case _DeviceIdentity() when $default != null:
return $default(_that.chipId);case _:
  return null;

}
}

}

/// @nodoc


class _DeviceIdentity implements DeviceIdentity {
  const _DeviceIdentity(this.chipId);
  

@override final  String chipId;

/// Create a copy of DeviceIdentity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceIdentityCopyWith<_DeviceIdentity> get copyWith => __$DeviceIdentityCopyWithImpl<_DeviceIdentity>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceIdentity&&(identical(other.chipId, chipId) || other.chipId == chipId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,chipId);
}

@override
String toString() {
    return 'DeviceIdentity(chipId: $chipId)';
}


}

/// @nodoc
abstract mixin class _$DeviceIdentityCopyWith<$Res> implements $DeviceIdentityCopyWith<$Res> {
  factory _$DeviceIdentityCopyWith(_DeviceIdentity value, $Res Function(_DeviceIdentity) _then) = __$DeviceIdentityCopyWithImpl;
@override @useResult
$Res call({
 String chipId
});




}
/// @nodoc
class __$DeviceIdentityCopyWithImpl<$Res>
    implements _$DeviceIdentityCopyWith<$Res> {
  __$DeviceIdentityCopyWithImpl(this._self, this._then);

  final _DeviceIdentity _self;
  final $Res Function(_DeviceIdentity) _then;

/// Create a copy of DeviceIdentity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chipId = null,}) {
  return _then(_DeviceIdentity(
null == chipId ? _self.chipId : chipId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$DeviceInfo {

 DeviceModel get model; FirmwareVersion get version; Capabilities get capabilities; String? get gitVersion; DeviceIdentity? get identity; String? get bleAddress;
/// Create a copy of DeviceInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceInfoCopyWith<DeviceInfo> get copyWith => _$DeviceInfoCopyWithImpl<DeviceInfo>(this as DeviceInfo, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as DeviceInfo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceInfo&&(identical(other.model, _this.model) || other.model == _this.model)&&(identical(other.version, _this.version) || other.version == _this.version)&&(identical(other.capabilities, _this.capabilities) || other.capabilities == _this.capabilities)&&(identical(other.gitVersion, _this.gitVersion) || other.gitVersion == _this.gitVersion)&&(identical(other.identity, _this.identity) || other.identity == _this.identity)&&(identical(other.bleAddress, _this.bleAddress) || other.bleAddress == _this.bleAddress));
}


@override
int get hashCode {
  final _this = this as DeviceInfo;
  return Object.hash(runtimeType,_this.model,_this.version,_this.capabilities,_this.gitVersion,_this.identity,_this.bleAddress);
}

@override
String toString() {
  final _this = this as DeviceInfo;
  return 'DeviceInfo(model: ${_this.model}, version: ${_this.version}, capabilities: ${_this.capabilities}, gitVersion: ${_this.gitVersion}, identity: ${_this.identity}, bleAddress: ${_this.bleAddress})';
}


}

/// @nodoc
abstract mixin class $DeviceInfoCopyWith<$Res>  {
  factory $DeviceInfoCopyWith(DeviceInfo value, $Res Function(DeviceInfo) _then) = _$DeviceInfoCopyWithImpl;
@useResult
$Res call({
 DeviceModel model, FirmwareVersion version, Capabilities capabilities, String? gitVersion, DeviceIdentity? identity, String? bleAddress
});


$FirmwareVersionCopyWith<$Res> get version;$CapabilitiesCopyWith<$Res> get capabilities;$DeviceIdentityCopyWith<$Res>? get identity;

}
/// @nodoc
class _$DeviceInfoCopyWithImpl<$Res>
    implements $DeviceInfoCopyWith<$Res> {
  _$DeviceInfoCopyWithImpl(this._self, this._then);

  final DeviceInfo _self;
  final $Res Function(DeviceInfo) _then;

/// Create a copy of DeviceInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? model = null,Object? version = null,Object? capabilities = null,Object? gitVersion = freezed,Object? identity = freezed,Object? bleAddress = freezed,}) {
  return _then(DeviceInfo(
model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as DeviceModel,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as FirmwareVersion,capabilities: null == capabilities ? _self.capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as Capabilities,gitVersion: freezed == gitVersion ? _self.gitVersion : gitVersion // ignore: cast_nullable_to_non_nullable
as String?,identity: freezed == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as DeviceIdentity?,bleAddress: freezed == bleAddress ? _self.bleAddress : bleAddress // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of DeviceInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FirmwareVersionCopyWith<$Res> get version {
  
  return $FirmwareVersionCopyWith<$Res>(_self.version, (value) {
    return _then(_self.copyWith(version: value));
  });
}/// Create a copy of DeviceInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CapabilitiesCopyWith<$Res> get capabilities {
  
  return $CapabilitiesCopyWith<$Res>(_self.capabilities, (value) {
    return _then(_self.copyWith(capabilities: value));
  });
}/// Create a copy of DeviceInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceIdentityCopyWith<$Res>? get identity {
    if (_self.identity == null) {
    return null;
  }

  return $DeviceIdentityCopyWith<$Res>(_self.identity!, (value) {
    return _then(_self.copyWith(identity: value));
  });
}
}


/// Adds pattern-matching-related methods to [DeviceInfo].
extension DeviceInfoPatterns on DeviceInfo {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceInfo() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceInfo value)  $default,){
final _that = this;
switch (_that) {
case _DeviceInfo():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceInfo value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceInfo() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DeviceModel model,  FirmwareVersion version,  Capabilities capabilities,  String? gitVersion,  DeviceIdentity? identity,  String? bleAddress)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceInfo() when $default != null:
return $default(_that.model,_that.version,_that.capabilities,_that.gitVersion,_that.identity,_that.bleAddress);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DeviceModel model,  FirmwareVersion version,  Capabilities capabilities,  String? gitVersion,  DeviceIdentity? identity,  String? bleAddress)  $default,) {final _that = this;
switch (_that) {
case _DeviceInfo():
return $default(_that.model,_that.version,_that.capabilities,_that.gitVersion,_that.identity,_that.bleAddress);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DeviceModel model,  FirmwareVersion version,  Capabilities capabilities,  String? gitVersion,  DeviceIdentity? identity,  String? bleAddress)?  $default,) {final _that = this;
switch (_that) {
case _DeviceInfo() when $default != null:
return $default(_that.model,_that.version,_that.capabilities,_that.gitVersion,_that.identity,_that.bleAddress);case _:
  return null;

}
}

}

/// @nodoc


class _DeviceInfo implements DeviceInfo {
  const _DeviceInfo({required this.model, required this.version, required this.capabilities, this.gitVersion, this.identity, this.bleAddress});
  

@override final  DeviceModel model;
@override final  FirmwareVersion version;
@override final  Capabilities capabilities;
@override final  String? gitVersion;
@override final  DeviceIdentity? identity;
@override final  String? bleAddress;

/// Create a copy of DeviceInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceInfoCopyWith<_DeviceInfo> get copyWith => __$DeviceInfoCopyWithImpl<_DeviceInfo>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceInfo&&(identical(other.model, model) || other.model == model)&&(identical(other.version, version) || other.version == version)&&(identical(other.capabilities, capabilities) || other.capabilities == capabilities)&&(identical(other.gitVersion, gitVersion) || other.gitVersion == gitVersion)&&(identical(other.identity, identity) || other.identity == identity)&&(identical(other.bleAddress, bleAddress) || other.bleAddress == bleAddress));
}


@override
int get hashCode {
    return Object.hash(runtimeType,model,version,capabilities,gitVersion,identity,bleAddress);
}

@override
String toString() {
    return 'DeviceInfo(model: $model, version: $version, capabilities: $capabilities, gitVersion: $gitVersion, identity: $identity, bleAddress: $bleAddress)';
}


}

/// @nodoc
abstract mixin class _$DeviceInfoCopyWith<$Res> implements $DeviceInfoCopyWith<$Res> {
  factory _$DeviceInfoCopyWith(_DeviceInfo value, $Res Function(_DeviceInfo) _then) = __$DeviceInfoCopyWithImpl;
@override @useResult
$Res call({
 DeviceModel model, FirmwareVersion version, Capabilities capabilities, String? gitVersion, DeviceIdentity? identity, String? bleAddress
});


@override $FirmwareVersionCopyWith<$Res> get version;@override $CapabilitiesCopyWith<$Res> get capabilities;@override $DeviceIdentityCopyWith<$Res>? get identity;

}
/// @nodoc
class __$DeviceInfoCopyWithImpl<$Res>
    implements _$DeviceInfoCopyWith<$Res> {
  __$DeviceInfoCopyWithImpl(this._self, this._then);

  final _DeviceInfo _self;
  final $Res Function(_DeviceInfo) _then;

/// Create a copy of DeviceInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? model = null,Object? version = null,Object? capabilities = null,Object? gitVersion = freezed,Object? identity = freezed,Object? bleAddress = freezed,}) {
  return _then(_DeviceInfo(
model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as DeviceModel,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as FirmwareVersion,capabilities: null == capabilities ? _self.capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as Capabilities,gitVersion: freezed == gitVersion ? _self.gitVersion : gitVersion // ignore: cast_nullable_to_non_nullable
as String?,identity: freezed == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as DeviceIdentity?,bleAddress: freezed == bleAddress ? _self.bleAddress : bleAddress // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of DeviceInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FirmwareVersionCopyWith<$Res> get version {
  
  return $FirmwareVersionCopyWith<$Res>(_self.version, (value) {
    return _then(_self.copyWith(version: value));
  });
}/// Create a copy of DeviceInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CapabilitiesCopyWith<$Res> get capabilities {
  
  return $CapabilitiesCopyWith<$Res>(_self.capabilities, (value) {
    return _then(_self.copyWith(capabilities: value));
  });
}/// Create a copy of DeviceInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceIdentityCopyWith<$Res>? get identity {
    if (_self.identity == null) {
    return null;
  }

  return $DeviceIdentityCopyWith<$Res>(_self.identity!, (value) {
    return _then(_self.copyWith(identity: value));
  });
}
}

/// @nodoc
mixin _$Slot {

 int get index; TagType get hfType; TagType get lfType; bool get hfEnabled; bool get lfEnabled; String get hfNick; String get lfNick;
/// Create a copy of Slot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SlotCopyWith<Slot> get copyWith => _$SlotCopyWithImpl<Slot>(this as Slot, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Slot;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Slot&&(identical(other.index, _this.index) || other.index == _this.index)&&(identical(other.hfType, _this.hfType) || other.hfType == _this.hfType)&&(identical(other.lfType, _this.lfType) || other.lfType == _this.lfType)&&(identical(other.hfEnabled, _this.hfEnabled) || other.hfEnabled == _this.hfEnabled)&&(identical(other.lfEnabled, _this.lfEnabled) || other.lfEnabled == _this.lfEnabled)&&(identical(other.hfNick, _this.hfNick) || other.hfNick == _this.hfNick)&&(identical(other.lfNick, _this.lfNick) || other.lfNick == _this.lfNick));
}


@override
int get hashCode {
  final _this = this as Slot;
  return Object.hash(runtimeType,_this.index,_this.hfType,_this.lfType,_this.hfEnabled,_this.lfEnabled,_this.hfNick,_this.lfNick);
}

@override
String toString() {
  final _this = this as Slot;
  return 'Slot(index: ${_this.index}, hfType: ${_this.hfType}, lfType: ${_this.lfType}, hfEnabled: ${_this.hfEnabled}, lfEnabled: ${_this.lfEnabled}, hfNick: ${_this.hfNick}, lfNick: ${_this.lfNick})';
}


}

/// @nodoc
abstract mixin class $SlotCopyWith<$Res>  {
  factory $SlotCopyWith(Slot value, $Res Function(Slot) _then) = _$SlotCopyWithImpl;
@useResult
$Res call({
 int index, TagType hfType, TagType lfType, bool hfEnabled, bool lfEnabled, String hfNick, String lfNick
});




}
/// @nodoc
class _$SlotCopyWithImpl<$Res>
    implements $SlotCopyWith<$Res> {
  _$SlotCopyWithImpl(this._self, this._then);

  final Slot _self;
  final $Res Function(Slot) _then;

/// Create a copy of Slot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? index = null,Object? hfType = null,Object? lfType = null,Object? hfEnabled = null,Object? lfEnabled = null,Object? hfNick = null,Object? lfNick = null,}) {
  return _then(Slot(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,hfType: null == hfType ? _self.hfType : hfType // ignore: cast_nullable_to_non_nullable
as TagType,lfType: null == lfType ? _self.lfType : lfType // ignore: cast_nullable_to_non_nullable
as TagType,hfEnabled: null == hfEnabled ? _self.hfEnabled : hfEnabled // ignore: cast_nullable_to_non_nullable
as bool,lfEnabled: null == lfEnabled ? _self.lfEnabled : lfEnabled // ignore: cast_nullable_to_non_nullable
as bool,hfNick: null == hfNick ? _self.hfNick : hfNick // ignore: cast_nullable_to_non_nullable
as String,lfNick: null == lfNick ? _self.lfNick : lfNick // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Slot].
extension SlotPatterns on Slot {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Slot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Slot() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Slot value)  $default,){
final _that = this;
switch (_that) {
case _Slot():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Slot value)?  $default,){
final _that = this;
switch (_that) {
case _Slot() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int index,  TagType hfType,  TagType lfType,  bool hfEnabled,  bool lfEnabled,  String hfNick,  String lfNick)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Slot() when $default != null:
return $default(_that.index,_that.hfType,_that.lfType,_that.hfEnabled,_that.lfEnabled,_that.hfNick,_that.lfNick);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int index,  TagType hfType,  TagType lfType,  bool hfEnabled,  bool lfEnabled,  String hfNick,  String lfNick)  $default,) {final _that = this;
switch (_that) {
case _Slot():
return $default(_that.index,_that.hfType,_that.lfType,_that.hfEnabled,_that.lfEnabled,_that.hfNick,_that.lfNick);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int index,  TagType hfType,  TagType lfType,  bool hfEnabled,  bool lfEnabled,  String hfNick,  String lfNick)?  $default,) {final _that = this;
switch (_that) {
case _Slot() when $default != null:
return $default(_that.index,_that.hfType,_that.lfType,_that.hfEnabled,_that.lfEnabled,_that.hfNick,_that.lfNick);case _:
  return null;

}
}

}

/// @nodoc


class _Slot implements Slot {
  const _Slot({required this.index, required this.hfType, required this.lfType, required this.hfEnabled, required this.lfEnabled, this.hfNick = '', this.lfNick = ''});
  

@override final  int index;
@override final  TagType hfType;
@override final  TagType lfType;
@override final  bool hfEnabled;
@override final  bool lfEnabled;
@override@JsonKey() final  String hfNick;
@override@JsonKey() final  String lfNick;

/// Create a copy of Slot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SlotCopyWith<_Slot> get copyWith => __$SlotCopyWithImpl<_Slot>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Slot&&(identical(other.index, index) || other.index == index)&&(identical(other.hfType, hfType) || other.hfType == hfType)&&(identical(other.lfType, lfType) || other.lfType == lfType)&&(identical(other.hfEnabled, hfEnabled) || other.hfEnabled == hfEnabled)&&(identical(other.lfEnabled, lfEnabled) || other.lfEnabled == lfEnabled)&&(identical(other.hfNick, hfNick) || other.hfNick == hfNick)&&(identical(other.lfNick, lfNick) || other.lfNick == lfNick));
}


@override
int get hashCode {
    return Object.hash(runtimeType,index,hfType,lfType,hfEnabled,lfEnabled,hfNick,lfNick);
}

@override
String toString() {
    return 'Slot(index: $index, hfType: $hfType, lfType: $lfType, hfEnabled: $hfEnabled, lfEnabled: $lfEnabled, hfNick: $hfNick, lfNick: $lfNick)';
}


}

/// @nodoc
abstract mixin class _$SlotCopyWith<$Res> implements $SlotCopyWith<$Res> {
  factory _$SlotCopyWith(_Slot value, $Res Function(_Slot) _then) = __$SlotCopyWithImpl;
@override @useResult
$Res call({
 int index, TagType hfType, TagType lfType, bool hfEnabled, bool lfEnabled, String hfNick, String lfNick
});




}
/// @nodoc
class __$SlotCopyWithImpl<$Res>
    implements _$SlotCopyWith<$Res> {
  __$SlotCopyWithImpl(this._self, this._then);

  final _Slot _self;
  final $Res Function(_Slot) _then;

/// Create a copy of Slot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? index = null,Object? hfType = null,Object? lfType = null,Object? hfEnabled = null,Object? lfEnabled = null,Object? hfNick = null,Object? lfNick = null,}) {
  return _then(_Slot(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,hfType: null == hfType ? _self.hfType : hfType // ignore: cast_nullable_to_non_nullable
as TagType,lfType: null == lfType ? _self.lfType : lfType // ignore: cast_nullable_to_non_nullable
as TagType,hfEnabled: null == hfEnabled ? _self.hfEnabled : hfEnabled // ignore: cast_nullable_to_non_nullable
as bool,lfEnabled: null == lfEnabled ? _self.lfEnabled : lfEnabled // ignore: cast_nullable_to_non_nullable
as bool,hfNick: null == hfNick ? _self.hfNick : hfNick // ignore: cast_nullable_to_non_nullable
as String,lfNick: null == lfNick ? _self.lfNick : lfNick // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$BatteryInfo {

 int get millivolts; int get percent;
/// Create a copy of BatteryInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BatteryInfoCopyWith<BatteryInfo> get copyWith => _$BatteryInfoCopyWithImpl<BatteryInfo>(this as BatteryInfo, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as BatteryInfo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BatteryInfo&&(identical(other.millivolts, _this.millivolts) || other.millivolts == _this.millivolts)&&(identical(other.percent, _this.percent) || other.percent == _this.percent));
}


@override
int get hashCode {
  final _this = this as BatteryInfo;
  return Object.hash(runtimeType,_this.millivolts,_this.percent);
}

@override
String toString() {
  final _this = this as BatteryInfo;
  return 'BatteryInfo(millivolts: ${_this.millivolts}, percent: ${_this.percent})';
}


}

/// @nodoc
abstract mixin class $BatteryInfoCopyWith<$Res>  {
  factory $BatteryInfoCopyWith(BatteryInfo value, $Res Function(BatteryInfo) _then) = _$BatteryInfoCopyWithImpl;
@useResult
$Res call({
 int millivolts, int percent
});




}
/// @nodoc
class _$BatteryInfoCopyWithImpl<$Res>
    implements $BatteryInfoCopyWith<$Res> {
  _$BatteryInfoCopyWithImpl(this._self, this._then);

  final BatteryInfo _self;
  final $Res Function(BatteryInfo) _then;

/// Create a copy of BatteryInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? millivolts = null,Object? percent = null,}) {
  return _then(BatteryInfo(
millivolts: null == millivolts ? _self.millivolts : millivolts // ignore: cast_nullable_to_non_nullable
as int,percent: null == percent ? _self.percent : percent // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [BatteryInfo].
extension BatteryInfoPatterns on BatteryInfo {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BatteryInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BatteryInfo() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BatteryInfo value)  $default,){
final _that = this;
switch (_that) {
case _BatteryInfo():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BatteryInfo value)?  $default,){
final _that = this;
switch (_that) {
case _BatteryInfo() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int millivolts,  int percent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BatteryInfo() when $default != null:
return $default(_that.millivolts,_that.percent);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int millivolts,  int percent)  $default,) {final _that = this;
switch (_that) {
case _BatteryInfo():
return $default(_that.millivolts,_that.percent);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int millivolts,  int percent)?  $default,) {final _that = this;
switch (_that) {
case _BatteryInfo() when $default != null:
return $default(_that.millivolts,_that.percent);case _:
  return null;

}
}

}

/// @nodoc


class _BatteryInfo implements BatteryInfo {
  const _BatteryInfo({required this.millivolts, required this.percent});
  

@override final  int millivolts;
@override final  int percent;

/// Create a copy of BatteryInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BatteryInfoCopyWith<_BatteryInfo> get copyWith => __$BatteryInfoCopyWithImpl<_BatteryInfo>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BatteryInfo&&(identical(other.millivolts, millivolts) || other.millivolts == millivolts)&&(identical(other.percent, percent) || other.percent == percent));
}


@override
int get hashCode {
    return Object.hash(runtimeType,millivolts,percent);
}

@override
String toString() {
    return 'BatteryInfo(millivolts: $millivolts, percent: $percent)';
}


}

/// @nodoc
abstract mixin class _$BatteryInfoCopyWith<$Res> implements $BatteryInfoCopyWith<$Res> {
  factory _$BatteryInfoCopyWith(_BatteryInfo value, $Res Function(_BatteryInfo) _then) = __$BatteryInfoCopyWithImpl;
@override @useResult
$Res call({
 int millivolts, int percent
});




}
/// @nodoc
class __$BatteryInfoCopyWithImpl<$Res>
    implements _$BatteryInfoCopyWith<$Res> {
  __$BatteryInfoCopyWithImpl(this._self, this._then);

  final _BatteryInfo _self;
  final $Res Function(_BatteryInfo) _then;

/// Create a copy of BatteryInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? millivolts = null,Object? percent = null,}) {
  return _then(_BatteryInfo(
millivolts: null == millivolts ? _self.millivolts : millivolts // ignore: cast_nullable_to_non_nullable
as int,percent: null == percent ? _self.percent : percent // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$DeviceSettings {

 int get version; AnimationMode get animation; ButtonFunction get buttonA; ButtonFunction get buttonB; ButtonFunction get longButtonA; ButtonFunction get longButtonB; bool get blePairingEnabled; String get blePairingKey; int? get sleepTimeoutSeconds;
/// Create a copy of DeviceSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceSettingsCopyWith<DeviceSettings> get copyWith => _$DeviceSettingsCopyWithImpl<DeviceSettings>(this as DeviceSettings, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as DeviceSettings;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceSettings&&(identical(other.version, _this.version) || other.version == _this.version)&&(identical(other.animation, _this.animation) || other.animation == _this.animation)&&(identical(other.buttonA, _this.buttonA) || other.buttonA == _this.buttonA)&&(identical(other.buttonB, _this.buttonB) || other.buttonB == _this.buttonB)&&(identical(other.longButtonA, _this.longButtonA) || other.longButtonA == _this.longButtonA)&&(identical(other.longButtonB, _this.longButtonB) || other.longButtonB == _this.longButtonB)&&(identical(other.blePairingEnabled, _this.blePairingEnabled) || other.blePairingEnabled == _this.blePairingEnabled)&&(identical(other.blePairingKey, _this.blePairingKey) || other.blePairingKey == _this.blePairingKey)&&(identical(other.sleepTimeoutSeconds, _this.sleepTimeoutSeconds) || other.sleepTimeoutSeconds == _this.sleepTimeoutSeconds));
}


@override
int get hashCode {
  final _this = this as DeviceSettings;
  return Object.hash(runtimeType,_this.version,_this.animation,_this.buttonA,_this.buttonB,_this.longButtonA,_this.longButtonB,_this.blePairingEnabled,_this.blePairingKey,_this.sleepTimeoutSeconds);
}

@override
String toString() {
  final _this = this as DeviceSettings;
  return 'DeviceSettings(version: ${_this.version}, animation: ${_this.animation}, buttonA: ${_this.buttonA}, buttonB: ${_this.buttonB}, longButtonA: ${_this.longButtonA}, longButtonB: ${_this.longButtonB}, blePairingEnabled: ${_this.blePairingEnabled}, blePairingKey: ${_this.blePairingKey}, sleepTimeoutSeconds: ${_this.sleepTimeoutSeconds})';
}


}

/// @nodoc
abstract mixin class $DeviceSettingsCopyWith<$Res>  {
  factory $DeviceSettingsCopyWith(DeviceSettings value, $Res Function(DeviceSettings) _then) = _$DeviceSettingsCopyWithImpl;
@useResult
$Res call({
 int version, AnimationMode animation, ButtonFunction buttonA, ButtonFunction buttonB, ButtonFunction longButtonA, ButtonFunction longButtonB, bool blePairingEnabled, String blePairingKey, int? sleepTimeoutSeconds
});




}
/// @nodoc
class _$DeviceSettingsCopyWithImpl<$Res>
    implements $DeviceSettingsCopyWith<$Res> {
  _$DeviceSettingsCopyWithImpl(this._self, this._then);

  final DeviceSettings _self;
  final $Res Function(DeviceSettings) _then;

/// Create a copy of DeviceSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? animation = null,Object? buttonA = null,Object? buttonB = null,Object? longButtonA = null,Object? longButtonB = null,Object? blePairingEnabled = null,Object? blePairingKey = null,Object? sleepTimeoutSeconds = freezed,}) {
  return _then(DeviceSettings(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,animation: null == animation ? _self.animation : animation // ignore: cast_nullable_to_non_nullable
as AnimationMode,buttonA: null == buttonA ? _self.buttonA : buttonA // ignore: cast_nullable_to_non_nullable
as ButtonFunction,buttonB: null == buttonB ? _self.buttonB : buttonB // ignore: cast_nullable_to_non_nullable
as ButtonFunction,longButtonA: null == longButtonA ? _self.longButtonA : longButtonA // ignore: cast_nullable_to_non_nullable
as ButtonFunction,longButtonB: null == longButtonB ? _self.longButtonB : longButtonB // ignore: cast_nullable_to_non_nullable
as ButtonFunction,blePairingEnabled: null == blePairingEnabled ? _self.blePairingEnabled : blePairingEnabled // ignore: cast_nullable_to_non_nullable
as bool,blePairingKey: null == blePairingKey ? _self.blePairingKey : blePairingKey // ignore: cast_nullable_to_non_nullable
as String,sleepTimeoutSeconds: freezed == sleepTimeoutSeconds ? _self.sleepTimeoutSeconds : sleepTimeoutSeconds // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [DeviceSettings].
extension DeviceSettingsPatterns on DeviceSettings {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceSettings() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceSettings value)  $default,){
final _that = this;
switch (_that) {
case _DeviceSettings():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceSettings value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceSettings() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int version,  AnimationMode animation,  ButtonFunction buttonA,  ButtonFunction buttonB,  ButtonFunction longButtonA,  ButtonFunction longButtonB,  bool blePairingEnabled,  String blePairingKey,  int? sleepTimeoutSeconds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceSettings() when $default != null:
return $default(_that.version,_that.animation,_that.buttonA,_that.buttonB,_that.longButtonA,_that.longButtonB,_that.blePairingEnabled,_that.blePairingKey,_that.sleepTimeoutSeconds);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int version,  AnimationMode animation,  ButtonFunction buttonA,  ButtonFunction buttonB,  ButtonFunction longButtonA,  ButtonFunction longButtonB,  bool blePairingEnabled,  String blePairingKey,  int? sleepTimeoutSeconds)  $default,) {final _that = this;
switch (_that) {
case _DeviceSettings():
return $default(_that.version,_that.animation,_that.buttonA,_that.buttonB,_that.longButtonA,_that.longButtonB,_that.blePairingEnabled,_that.blePairingKey,_that.sleepTimeoutSeconds);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int version,  AnimationMode animation,  ButtonFunction buttonA,  ButtonFunction buttonB,  ButtonFunction longButtonA,  ButtonFunction longButtonB,  bool blePairingEnabled,  String blePairingKey,  int? sleepTimeoutSeconds)?  $default,) {final _that = this;
switch (_that) {
case _DeviceSettings() when $default != null:
return $default(_that.version,_that.animation,_that.buttonA,_that.buttonB,_that.longButtonA,_that.longButtonB,_that.blePairingEnabled,_that.blePairingKey,_that.sleepTimeoutSeconds);case _:
  return null;

}
}

}

/// @nodoc


class _DeviceSettings implements DeviceSettings {
  const _DeviceSettings({required this.version, required this.animation, required this.buttonA, required this.buttonB, required this.longButtonA, required this.longButtonB, required this.blePairingEnabled, required this.blePairingKey, this.sleepTimeoutSeconds});
  

@override final  int version;
@override final  AnimationMode animation;
@override final  ButtonFunction buttonA;
@override final  ButtonFunction buttonB;
@override final  ButtonFunction longButtonA;
@override final  ButtonFunction longButtonB;
@override final  bool blePairingEnabled;
@override final  String blePairingKey;
@override final  int? sleepTimeoutSeconds;

/// Create a copy of DeviceSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceSettingsCopyWith<_DeviceSettings> get copyWith => __$DeviceSettingsCopyWithImpl<_DeviceSettings>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceSettings&&(identical(other.version, version) || other.version == version)&&(identical(other.animation, animation) || other.animation == animation)&&(identical(other.buttonA, buttonA) || other.buttonA == buttonA)&&(identical(other.buttonB, buttonB) || other.buttonB == buttonB)&&(identical(other.longButtonA, longButtonA) || other.longButtonA == longButtonA)&&(identical(other.longButtonB, longButtonB) || other.longButtonB == longButtonB)&&(identical(other.blePairingEnabled, blePairingEnabled) || other.blePairingEnabled == blePairingEnabled)&&(identical(other.blePairingKey, blePairingKey) || other.blePairingKey == blePairingKey)&&(identical(other.sleepTimeoutSeconds, sleepTimeoutSeconds) || other.sleepTimeoutSeconds == sleepTimeoutSeconds));
}


@override
int get hashCode {
    return Object.hash(runtimeType,version,animation,buttonA,buttonB,longButtonA,longButtonB,blePairingEnabled,blePairingKey,sleepTimeoutSeconds);
}

@override
String toString() {
    return 'DeviceSettings(version: $version, animation: $animation, buttonA: $buttonA, buttonB: $buttonB, longButtonA: $longButtonA, longButtonB: $longButtonB, blePairingEnabled: $blePairingEnabled, blePairingKey: $blePairingKey, sleepTimeoutSeconds: $sleepTimeoutSeconds)';
}


}

/// @nodoc
abstract mixin class _$DeviceSettingsCopyWith<$Res> implements $DeviceSettingsCopyWith<$Res> {
  factory _$DeviceSettingsCopyWith(_DeviceSettings value, $Res Function(_DeviceSettings) _then) = __$DeviceSettingsCopyWithImpl;
@override @useResult
$Res call({
 int version, AnimationMode animation, ButtonFunction buttonA, ButtonFunction buttonB, ButtonFunction longButtonA, ButtonFunction longButtonB, bool blePairingEnabled, String blePairingKey, int? sleepTimeoutSeconds
});




}
/// @nodoc
class __$DeviceSettingsCopyWithImpl<$Res>
    implements _$DeviceSettingsCopyWith<$Res> {
  __$DeviceSettingsCopyWithImpl(this._self, this._then);

  final _DeviceSettings _self;
  final $Res Function(_DeviceSettings) _then;

/// Create a copy of DeviceSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? animation = null,Object? buttonA = null,Object? buttonB = null,Object? longButtonA = null,Object? longButtonB = null,Object? blePairingEnabled = null,Object? blePairingKey = null,Object? sleepTimeoutSeconds = freezed,}) {
  return _then(_DeviceSettings(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,animation: null == animation ? _self.animation : animation // ignore: cast_nullable_to_non_nullable
as AnimationMode,buttonA: null == buttonA ? _self.buttonA : buttonA // ignore: cast_nullable_to_non_nullable
as ButtonFunction,buttonB: null == buttonB ? _self.buttonB : buttonB // ignore: cast_nullable_to_non_nullable
as ButtonFunction,longButtonA: null == longButtonA ? _self.longButtonA : longButtonA // ignore: cast_nullable_to_non_nullable
as ButtonFunction,longButtonB: null == longButtonB ? _self.longButtonB : longButtonB // ignore: cast_nullable_to_non_nullable
as ButtonFunction,blePairingEnabled: null == blePairingEnabled ? _self.blePairingEnabled : blePairingEnabled // ignore: cast_nullable_to_non_nullable
as bool,blePairingKey: null == blePairingKey ? _self.blePairingKey : blePairingKey // ignore: cast_nullable_to_non_nullable
as String,sleepTimeoutSeconds: freezed == sleepTimeoutSeconds ? _self.sleepTimeoutSeconds : sleepTimeoutSeconds // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$Hf14aTag {

 Uint8List get uid; Uint8List get atqa; int get sak; Uint8List get ats;
/// Create a copy of Hf14aTag
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Hf14aTagCopyWith<Hf14aTag> get copyWith => _$Hf14aTagCopyWithImpl<Hf14aTag>(this as Hf14aTag, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Hf14aTag;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Hf14aTag&&const DeepCollectionEquality().equals(other.uid, _this.uid)&&const DeepCollectionEquality().equals(other.atqa, _this.atqa)&&(identical(other.sak, _this.sak) || other.sak == _this.sak)&&const DeepCollectionEquality().equals(other.ats, _this.ats));
}


@override
int get hashCode {
  final _this = this as Hf14aTag;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.uid),const DeepCollectionEquality().hash(_this.atqa),_this.sak,const DeepCollectionEquality().hash(_this.ats));
}

@override
String toString() {
  final _this = this as Hf14aTag;
  return 'Hf14aTag(uid: ${_this.uid}, atqa: ${_this.atqa}, sak: ${_this.sak}, ats: ${_this.ats})';
}


}

/// @nodoc
abstract mixin class $Hf14aTagCopyWith<$Res>  {
  factory $Hf14aTagCopyWith(Hf14aTag value, $Res Function(Hf14aTag) _then) = _$Hf14aTagCopyWithImpl;
@useResult
$Res call({
 Uint8List uid, Uint8List atqa, int sak, Uint8List ats
});




}
/// @nodoc
class _$Hf14aTagCopyWithImpl<$Res>
    implements $Hf14aTagCopyWith<$Res> {
  _$Hf14aTagCopyWithImpl(this._self, this._then);

  final Hf14aTag _self;
  final $Res Function(Hf14aTag) _then;

/// Create a copy of Hf14aTag
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uid = null,Object? atqa = null,Object? sak = null,Object? ats = null,}) {
  return _then(Hf14aTag(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as Uint8List,atqa: null == atqa ? _self.atqa : atqa // ignore: cast_nullable_to_non_nullable
as Uint8List,sak: null == sak ? _self.sak : sak // ignore: cast_nullable_to_non_nullable
as int,ats: null == ats ? _self.ats : ats // ignore: cast_nullable_to_non_nullable
as Uint8List,
  ));
}

}


/// Adds pattern-matching-related methods to [Hf14aTag].
extension Hf14aTagPatterns on Hf14aTag {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Hf14aTag value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Hf14aTag() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Hf14aTag value)  $default,){
final _that = this;
switch (_that) {
case _Hf14aTag():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Hf14aTag value)?  $default,){
final _that = this;
switch (_that) {
case _Hf14aTag() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Uint8List uid,  Uint8List atqa,  int sak,  Uint8List ats)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Hf14aTag() when $default != null:
return $default(_that.uid,_that.atqa,_that.sak,_that.ats);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Uint8List uid,  Uint8List atqa,  int sak,  Uint8List ats)  $default,) {final _that = this;
switch (_that) {
case _Hf14aTag():
return $default(_that.uid,_that.atqa,_that.sak,_that.ats);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Uint8List uid,  Uint8List atqa,  int sak,  Uint8List ats)?  $default,) {final _that = this;
switch (_that) {
case _Hf14aTag() when $default != null:
return $default(_that.uid,_that.atqa,_that.sak,_that.ats);case _:
  return null;

}
}

}

/// @nodoc


class _Hf14aTag extends Hf14aTag {
  const _Hf14aTag({required this.uid, required this.atqa, required this.sak, required this.ats}): super._();
  

@override final  Uint8List uid;
@override final  Uint8List atqa;
@override final  int sak;
@override final  Uint8List ats;

/// Create a copy of Hf14aTag
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$Hf14aTagCopyWith<_Hf14aTag> get copyWith => __$Hf14aTagCopyWithImpl<_Hf14aTag>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Hf14aTag&&const DeepCollectionEquality().equals(other.uid, uid)&&const DeepCollectionEquality().equals(other.atqa, atqa)&&(identical(other.sak, sak) || other.sak == sak)&&const DeepCollectionEquality().equals(other.ats, ats));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(uid),const DeepCollectionEquality().hash(atqa),sak,const DeepCollectionEquality().hash(ats));
}

@override
String toString() {
    return 'Hf14aTag(uid: $uid, atqa: $atqa, sak: $sak, ats: $ats)';
}


}

/// @nodoc
abstract mixin class _$Hf14aTagCopyWith<$Res> implements $Hf14aTagCopyWith<$Res> {
  factory _$Hf14aTagCopyWith(_Hf14aTag value, $Res Function(_Hf14aTag) _then) = __$Hf14aTagCopyWithImpl;
@override @useResult
$Res call({
 Uint8List uid, Uint8List atqa, int sak, Uint8List ats
});




}
/// @nodoc
class __$Hf14aTagCopyWithImpl<$Res>
    implements _$Hf14aTagCopyWith<$Res> {
  __$Hf14aTagCopyWithImpl(this._self, this._then);

  final _Hf14aTag _self;
  final $Res Function(_Hf14aTag) _then;

/// Create a copy of Hf14aTag
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uid = null,Object? atqa = null,Object? sak = null,Object? ats = null,}) {
  return _then(_Hf14aTag(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as Uint8List,atqa: null == atqa ? _self.atqa : atqa // ignore: cast_nullable_to_non_nullable
as Uint8List,sak: null == sak ? _self.sak : sak // ignore: cast_nullable_to_non_nullable
as int,ats: null == ats ? _self.ats : ats // ignore: cast_nullable_to_non_nullable
as Uint8List,
  ));
}


}

/// @nodoc
mixin _$Mf1EmulatorConfig {

 bool get detectionEnabled; bool get gen1a; bool get gen2; bool get blockAntiColl; Mf1WriteMode get writeMode;
/// Create a copy of Mf1EmulatorConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Mf1EmulatorConfigCopyWith<Mf1EmulatorConfig> get copyWith => _$Mf1EmulatorConfigCopyWithImpl<Mf1EmulatorConfig>(this as Mf1EmulatorConfig, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Mf1EmulatorConfig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Mf1EmulatorConfig&&(identical(other.detectionEnabled, _this.detectionEnabled) || other.detectionEnabled == _this.detectionEnabled)&&(identical(other.gen1a, _this.gen1a) || other.gen1a == _this.gen1a)&&(identical(other.gen2, _this.gen2) || other.gen2 == _this.gen2)&&(identical(other.blockAntiColl, _this.blockAntiColl) || other.blockAntiColl == _this.blockAntiColl)&&(identical(other.writeMode, _this.writeMode) || other.writeMode == _this.writeMode));
}


@override
int get hashCode {
  final _this = this as Mf1EmulatorConfig;
  return Object.hash(runtimeType,_this.detectionEnabled,_this.gen1a,_this.gen2,_this.blockAntiColl,_this.writeMode);
}

@override
String toString() {
  final _this = this as Mf1EmulatorConfig;
  return 'Mf1EmulatorConfig(detectionEnabled: ${_this.detectionEnabled}, gen1a: ${_this.gen1a}, gen2: ${_this.gen2}, blockAntiColl: ${_this.blockAntiColl}, writeMode: ${_this.writeMode})';
}


}

/// @nodoc
abstract mixin class $Mf1EmulatorConfigCopyWith<$Res>  {
  factory $Mf1EmulatorConfigCopyWith(Mf1EmulatorConfig value, $Res Function(Mf1EmulatorConfig) _then) = _$Mf1EmulatorConfigCopyWithImpl;
@useResult
$Res call({
 bool detectionEnabled, bool gen1a, bool gen2, bool blockAntiColl, Mf1WriteMode writeMode
});




}
/// @nodoc
class _$Mf1EmulatorConfigCopyWithImpl<$Res>
    implements $Mf1EmulatorConfigCopyWith<$Res> {
  _$Mf1EmulatorConfigCopyWithImpl(this._self, this._then);

  final Mf1EmulatorConfig _self;
  final $Res Function(Mf1EmulatorConfig) _then;

/// Create a copy of Mf1EmulatorConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? detectionEnabled = null,Object? gen1a = null,Object? gen2 = null,Object? blockAntiColl = null,Object? writeMode = null,}) {
  return _then(Mf1EmulatorConfig(
detectionEnabled: null == detectionEnabled ? _self.detectionEnabled : detectionEnabled // ignore: cast_nullable_to_non_nullable
as bool,gen1a: null == gen1a ? _self.gen1a : gen1a // ignore: cast_nullable_to_non_nullable
as bool,gen2: null == gen2 ? _self.gen2 : gen2 // ignore: cast_nullable_to_non_nullable
as bool,blockAntiColl: null == blockAntiColl ? _self.blockAntiColl : blockAntiColl // ignore: cast_nullable_to_non_nullable
as bool,writeMode: null == writeMode ? _self.writeMode : writeMode // ignore: cast_nullable_to_non_nullable
as Mf1WriteMode,
  ));
}

}


/// Adds pattern-matching-related methods to [Mf1EmulatorConfig].
extension Mf1EmulatorConfigPatterns on Mf1EmulatorConfig {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Mf1EmulatorConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Mf1EmulatorConfig() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Mf1EmulatorConfig value)  $default,){
final _that = this;
switch (_that) {
case _Mf1EmulatorConfig():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Mf1EmulatorConfig value)?  $default,){
final _that = this;
switch (_that) {
case _Mf1EmulatorConfig() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool detectionEnabled,  bool gen1a,  bool gen2,  bool blockAntiColl,  Mf1WriteMode writeMode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Mf1EmulatorConfig() when $default != null:
return $default(_that.detectionEnabled,_that.gen1a,_that.gen2,_that.blockAntiColl,_that.writeMode);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool detectionEnabled,  bool gen1a,  bool gen2,  bool blockAntiColl,  Mf1WriteMode writeMode)  $default,) {final _that = this;
switch (_that) {
case _Mf1EmulatorConfig():
return $default(_that.detectionEnabled,_that.gen1a,_that.gen2,_that.blockAntiColl,_that.writeMode);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool detectionEnabled,  bool gen1a,  bool gen2,  bool blockAntiColl,  Mf1WriteMode writeMode)?  $default,) {final _that = this;
switch (_that) {
case _Mf1EmulatorConfig() when $default != null:
return $default(_that.detectionEnabled,_that.gen1a,_that.gen2,_that.blockAntiColl,_that.writeMode);case _:
  return null;

}
}

}

/// @nodoc


class _Mf1EmulatorConfig implements Mf1EmulatorConfig {
  const _Mf1EmulatorConfig({required this.detectionEnabled, required this.gen1a, required this.gen2, required this.blockAntiColl, required this.writeMode});
  

@override final  bool detectionEnabled;
@override final  bool gen1a;
@override final  bool gen2;
@override final  bool blockAntiColl;
@override final  Mf1WriteMode writeMode;

/// Create a copy of Mf1EmulatorConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$Mf1EmulatorConfigCopyWith<_Mf1EmulatorConfig> get copyWith => __$Mf1EmulatorConfigCopyWithImpl<_Mf1EmulatorConfig>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Mf1EmulatorConfig&&(identical(other.detectionEnabled, detectionEnabled) || other.detectionEnabled == detectionEnabled)&&(identical(other.gen1a, gen1a) || other.gen1a == gen1a)&&(identical(other.gen2, gen2) || other.gen2 == gen2)&&(identical(other.blockAntiColl, blockAntiColl) || other.blockAntiColl == blockAntiColl)&&(identical(other.writeMode, writeMode) || other.writeMode == writeMode));
}


@override
int get hashCode {
    return Object.hash(runtimeType,detectionEnabled,gen1a,gen2,blockAntiColl,writeMode);
}

@override
String toString() {
    return 'Mf1EmulatorConfig(detectionEnabled: $detectionEnabled, gen1a: $gen1a, gen2: $gen2, blockAntiColl: $blockAntiColl, writeMode: $writeMode)';
}


}

/// @nodoc
abstract mixin class _$Mf1EmulatorConfigCopyWith<$Res> implements $Mf1EmulatorConfigCopyWith<$Res> {
  factory _$Mf1EmulatorConfigCopyWith(_Mf1EmulatorConfig value, $Res Function(_Mf1EmulatorConfig) _then) = __$Mf1EmulatorConfigCopyWithImpl;
@override @useResult
$Res call({
 bool detectionEnabled, bool gen1a, bool gen2, bool blockAntiColl, Mf1WriteMode writeMode
});




}
/// @nodoc
class __$Mf1EmulatorConfigCopyWithImpl<$Res>
    implements _$Mf1EmulatorConfigCopyWith<$Res> {
  __$Mf1EmulatorConfigCopyWithImpl(this._self, this._then);

  final _Mf1EmulatorConfig _self;
  final $Res Function(_Mf1EmulatorConfig) _then;

/// Create a copy of Mf1EmulatorConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? detectionEnabled = null,Object? gen1a = null,Object? gen2 = null,Object? blockAntiColl = null,Object? writeMode = null,}) {
  return _then(_Mf1EmulatorConfig(
detectionEnabled: null == detectionEnabled ? _self.detectionEnabled : detectionEnabled // ignore: cast_nullable_to_non_nullable
as bool,gen1a: null == gen1a ? _self.gen1a : gen1a // ignore: cast_nullable_to_non_nullable
as bool,gen2: null == gen2 ? _self.gen2 : gen2 // ignore: cast_nullable_to_non_nullable
as bool,blockAntiColl: null == blockAntiColl ? _self.blockAntiColl : blockAntiColl // ignore: cast_nullable_to_non_nullable
as bool,writeMode: null == writeMode ? _self.writeMode : writeMode // ignore: cast_nullable_to_non_nullable
as Mf1WriteMode,
  ));
}


}

/// @nodoc
mixin _$SectorKeys {

 int get sector; Uint8List? get keyA; Uint8List? get keyB;
/// Create a copy of SectorKeys
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SectorKeysCopyWith<SectorKeys> get copyWith => _$SectorKeysCopyWithImpl<SectorKeys>(this as SectorKeys, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SectorKeys;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SectorKeys&&(identical(other.sector, _this.sector) || other.sector == _this.sector)&&const DeepCollectionEquality().equals(other.keyA, _this.keyA)&&const DeepCollectionEquality().equals(other.keyB, _this.keyB));
}


@override
int get hashCode {
  final _this = this as SectorKeys;
  return Object.hash(runtimeType,_this.sector,const DeepCollectionEquality().hash(_this.keyA),const DeepCollectionEquality().hash(_this.keyB));
}

@override
String toString() {
  final _this = this as SectorKeys;
  return 'SectorKeys(sector: ${_this.sector}, keyA: ${_this.keyA}, keyB: ${_this.keyB})';
}


}

/// @nodoc
abstract mixin class $SectorKeysCopyWith<$Res>  {
  factory $SectorKeysCopyWith(SectorKeys value, $Res Function(SectorKeys) _then) = _$SectorKeysCopyWithImpl;
@useResult
$Res call({
 int sector, Uint8List? keyA, Uint8List? keyB
});




}
/// @nodoc
class _$SectorKeysCopyWithImpl<$Res>
    implements $SectorKeysCopyWith<$Res> {
  _$SectorKeysCopyWithImpl(this._self, this._then);

  final SectorKeys _self;
  final $Res Function(SectorKeys) _then;

/// Create a copy of SectorKeys
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sector = null,Object? keyA = freezed,Object? keyB = freezed,}) {
  return _then(SectorKeys(
sector: null == sector ? _self.sector : sector // ignore: cast_nullable_to_non_nullable
as int,keyA: freezed == keyA ? _self.keyA : keyA // ignore: cast_nullable_to_non_nullable
as Uint8List?,keyB: freezed == keyB ? _self.keyB : keyB // ignore: cast_nullable_to_non_nullable
as Uint8List?,
  ));
}

}


/// Adds pattern-matching-related methods to [SectorKeys].
extension SectorKeysPatterns on SectorKeys {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SectorKeys value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SectorKeys() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SectorKeys value)  $default,){
final _that = this;
switch (_that) {
case _SectorKeys():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SectorKeys value)?  $default,){
final _that = this;
switch (_that) {
case _SectorKeys() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int sector,  Uint8List? keyA,  Uint8List? keyB)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SectorKeys() when $default != null:
return $default(_that.sector,_that.keyA,_that.keyB);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int sector,  Uint8List? keyA,  Uint8List? keyB)  $default,) {final _that = this;
switch (_that) {
case _SectorKeys():
return $default(_that.sector,_that.keyA,_that.keyB);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int sector,  Uint8List? keyA,  Uint8List? keyB)?  $default,) {final _that = this;
switch (_that) {
case _SectorKeys() when $default != null:
return $default(_that.sector,_that.keyA,_that.keyB);case _:
  return null;

}
}

}

/// @nodoc


class _SectorKeys implements SectorKeys {
  const _SectorKeys({required this.sector, this.keyA, this.keyB});
  

@override final  int sector;
@override final  Uint8List? keyA;
@override final  Uint8List? keyB;

/// Create a copy of SectorKeys
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SectorKeysCopyWith<_SectorKeys> get copyWith => __$SectorKeysCopyWithImpl<_SectorKeys>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SectorKeys&&(identical(other.sector, sector) || other.sector == sector)&&const DeepCollectionEquality().equals(other.keyA, keyA)&&const DeepCollectionEquality().equals(other.keyB, keyB));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sector,const DeepCollectionEquality().hash(keyA),const DeepCollectionEquality().hash(keyB));
}

@override
String toString() {
    return 'SectorKeys(sector: $sector, keyA: $keyA, keyB: $keyB)';
}


}

/// @nodoc
abstract mixin class _$SectorKeysCopyWith<$Res> implements $SectorKeysCopyWith<$Res> {
  factory _$SectorKeysCopyWith(_SectorKeys value, $Res Function(_SectorKeys) _then) = __$SectorKeysCopyWithImpl;
@override @useResult
$Res call({
 int sector, Uint8List? keyA, Uint8List? keyB
});




}
/// @nodoc
class __$SectorKeysCopyWithImpl<$Res>
    implements _$SectorKeysCopyWith<$Res> {
  __$SectorKeysCopyWithImpl(this._self, this._then);

  final _SectorKeys _self;
  final $Res Function(_SectorKeys) _then;

/// Create a copy of SectorKeys
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sector = null,Object? keyA = freezed,Object? keyB = freezed,}) {
  return _then(_SectorKeys(
sector: null == sector ? _self.sector : sector // ignore: cast_nullable_to_non_nullable
as int,keyA: freezed == keyA ? _self.keyA : keyA // ignore: cast_nullable_to_non_nullable
as Uint8List?,keyB: freezed == keyB ? _self.keyB : keyB // ignore: cast_nullable_to_non_nullable
as Uint8List?,
  ));
}


}

/// @nodoc
mixin _$Mf1KeyCheckResult {

 List<SectorKeys> get sectors;
/// Create a copy of Mf1KeyCheckResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Mf1KeyCheckResultCopyWith<Mf1KeyCheckResult> get copyWith => _$Mf1KeyCheckResultCopyWithImpl<Mf1KeyCheckResult>(this as Mf1KeyCheckResult, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Mf1KeyCheckResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Mf1KeyCheckResult&&const DeepCollectionEquality().equals(other.sectors, _this.sectors));
}


@override
int get hashCode {
  final _this = this as Mf1KeyCheckResult;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.sectors));
}

@override
String toString() {
  final _this = this as Mf1KeyCheckResult;
  return 'Mf1KeyCheckResult(sectors: ${_this.sectors})';
}


}

/// @nodoc
abstract mixin class $Mf1KeyCheckResultCopyWith<$Res>  {
  factory $Mf1KeyCheckResultCopyWith(Mf1KeyCheckResult value, $Res Function(Mf1KeyCheckResult) _then) = _$Mf1KeyCheckResultCopyWithImpl;
@useResult
$Res call({
 List<SectorKeys> sectors
});




}
/// @nodoc
class _$Mf1KeyCheckResultCopyWithImpl<$Res>
    implements $Mf1KeyCheckResultCopyWith<$Res> {
  _$Mf1KeyCheckResultCopyWithImpl(this._self, this._then);

  final Mf1KeyCheckResult _self;
  final $Res Function(Mf1KeyCheckResult) _then;

/// Create a copy of Mf1KeyCheckResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sectors = null,}) {
  return _then(Mf1KeyCheckResult(
null == sectors ? _self.sectors : sectors // ignore: cast_nullable_to_non_nullable
as List<SectorKeys>,
  ));
}

}


/// Adds pattern-matching-related methods to [Mf1KeyCheckResult].
extension Mf1KeyCheckResultPatterns on Mf1KeyCheckResult {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Mf1KeyCheckResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Mf1KeyCheckResult() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Mf1KeyCheckResult value)  $default,){
final _that = this;
switch (_that) {
case _Mf1KeyCheckResult():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Mf1KeyCheckResult value)?  $default,){
final _that = this;
switch (_that) {
case _Mf1KeyCheckResult() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<SectorKeys> sectors)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Mf1KeyCheckResult() when $default != null:
return $default(_that.sectors);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<SectorKeys> sectors)  $default,) {final _that = this;
switch (_that) {
case _Mf1KeyCheckResult():
return $default(_that.sectors);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<SectorKeys> sectors)?  $default,) {final _that = this;
switch (_that) {
case _Mf1KeyCheckResult() when $default != null:
return $default(_that.sectors);case _:
  return null;

}
}

}

/// @nodoc


class _Mf1KeyCheckResult implements Mf1KeyCheckResult {
  const _Mf1KeyCheckResult( List<SectorKeys> sectors): _sectors = sectors;
  

 final  List<SectorKeys> _sectors;
@override List<SectorKeys> get sectors {
  if (_sectors is EqualUnmodifiableListView) return _sectors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sectors);
}


/// Create a copy of Mf1KeyCheckResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$Mf1KeyCheckResultCopyWith<_Mf1KeyCheckResult> get copyWith => __$Mf1KeyCheckResultCopyWithImpl<_Mf1KeyCheckResult>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Mf1KeyCheckResult&&const DeepCollectionEquality().equals(other.sectors, _sectors));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_sectors));
}

@override
String toString() {
    return 'Mf1KeyCheckResult(sectors: $sectors)';
}


}

/// @nodoc
abstract mixin class _$Mf1KeyCheckResultCopyWith<$Res> implements $Mf1KeyCheckResultCopyWith<$Res> {
  factory _$Mf1KeyCheckResultCopyWith(_Mf1KeyCheckResult value, $Res Function(_Mf1KeyCheckResult) _then) = __$Mf1KeyCheckResultCopyWithImpl;
@override @useResult
$Res call({
 List<SectorKeys> sectors
});




}
/// @nodoc
class __$Mf1KeyCheckResultCopyWithImpl<$Res>
    implements _$Mf1KeyCheckResultCopyWith<$Res> {
  __$Mf1KeyCheckResultCopyWithImpl(this._self, this._then);

  final _Mf1KeyCheckResult _self;
  final $Res Function(_Mf1KeyCheckResult) _then;

/// Create a copy of Mf1KeyCheckResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sectors = null,}) {
  return _then(_Mf1KeyCheckResult(
null == sectors ? _self._sectors : sectors // ignore: cast_nullable_to_non_nullable
as List<SectorKeys>,
  ));
}


}

/// @nodoc
mixin _$DetectionLogEntry {

 int get block; KeyType get keyType; bool get isNested; Uint8List get uid; int get nt; int get nr; int get ar;
/// Create a copy of DetectionLogEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DetectionLogEntryCopyWith<DetectionLogEntry> get copyWith => _$DetectionLogEntryCopyWithImpl<DetectionLogEntry>(this as DetectionLogEntry, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as DetectionLogEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetectionLogEntry&&(identical(other.block, _this.block) || other.block == _this.block)&&(identical(other.keyType, _this.keyType) || other.keyType == _this.keyType)&&(identical(other.isNested, _this.isNested) || other.isNested == _this.isNested)&&const DeepCollectionEquality().equals(other.uid, _this.uid)&&(identical(other.nt, _this.nt) || other.nt == _this.nt)&&(identical(other.nr, _this.nr) || other.nr == _this.nr)&&(identical(other.ar, _this.ar) || other.ar == _this.ar));
}


@override
int get hashCode {
  final _this = this as DetectionLogEntry;
  return Object.hash(runtimeType,_this.block,_this.keyType,_this.isNested,const DeepCollectionEquality().hash(_this.uid),_this.nt,_this.nr,_this.ar);
}

@override
String toString() {
  final _this = this as DetectionLogEntry;
  return 'DetectionLogEntry(block: ${_this.block}, keyType: ${_this.keyType}, isNested: ${_this.isNested}, uid: ${_this.uid}, nt: ${_this.nt}, nr: ${_this.nr}, ar: ${_this.ar})';
}


}

/// @nodoc
abstract mixin class $DetectionLogEntryCopyWith<$Res>  {
  factory $DetectionLogEntryCopyWith(DetectionLogEntry value, $Res Function(DetectionLogEntry) _then) = _$DetectionLogEntryCopyWithImpl;
@useResult
$Res call({
 int block, KeyType keyType, bool isNested, Uint8List uid, int nt, int nr, int ar
});




}
/// @nodoc
class _$DetectionLogEntryCopyWithImpl<$Res>
    implements $DetectionLogEntryCopyWith<$Res> {
  _$DetectionLogEntryCopyWithImpl(this._self, this._then);

  final DetectionLogEntry _self;
  final $Res Function(DetectionLogEntry) _then;

/// Create a copy of DetectionLogEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? block = null,Object? keyType = null,Object? isNested = null,Object? uid = null,Object? nt = null,Object? nr = null,Object? ar = null,}) {
  return _then(DetectionLogEntry(
block: null == block ? _self.block : block // ignore: cast_nullable_to_non_nullable
as int,keyType: null == keyType ? _self.keyType : keyType // ignore: cast_nullable_to_non_nullable
as KeyType,isNested: null == isNested ? _self.isNested : isNested // ignore: cast_nullable_to_non_nullable
as bool,uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as Uint8List,nt: null == nt ? _self.nt : nt // ignore: cast_nullable_to_non_nullable
as int,nr: null == nr ? _self.nr : nr // ignore: cast_nullable_to_non_nullable
as int,ar: null == ar ? _self.ar : ar // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [DetectionLogEntry].
extension DetectionLogEntryPatterns on DetectionLogEntry {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DetectionLogEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DetectionLogEntry() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DetectionLogEntry value)  $default,){
final _that = this;
switch (_that) {
case _DetectionLogEntry():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DetectionLogEntry value)?  $default,){
final _that = this;
switch (_that) {
case _DetectionLogEntry() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int block,  KeyType keyType,  bool isNested,  Uint8List uid,  int nt,  int nr,  int ar)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DetectionLogEntry() when $default != null:
return $default(_that.block,_that.keyType,_that.isNested,_that.uid,_that.nt,_that.nr,_that.ar);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int block,  KeyType keyType,  bool isNested,  Uint8List uid,  int nt,  int nr,  int ar)  $default,) {final _that = this;
switch (_that) {
case _DetectionLogEntry():
return $default(_that.block,_that.keyType,_that.isNested,_that.uid,_that.nt,_that.nr,_that.ar);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int block,  KeyType keyType,  bool isNested,  Uint8List uid,  int nt,  int nr,  int ar)?  $default,) {final _that = this;
switch (_that) {
case _DetectionLogEntry() when $default != null:
return $default(_that.block,_that.keyType,_that.isNested,_that.uid,_that.nt,_that.nr,_that.ar);case _:
  return null;

}
}

}

/// @nodoc


class _DetectionLogEntry implements DetectionLogEntry {
  const _DetectionLogEntry({required this.block, required this.keyType, required this.isNested, required this.uid, required this.nt, required this.nr, required this.ar});
  

@override final  int block;
@override final  KeyType keyType;
@override final  bool isNested;
@override final  Uint8List uid;
@override final  int nt;
@override final  int nr;
@override final  int ar;

/// Create a copy of DetectionLogEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DetectionLogEntryCopyWith<_DetectionLogEntry> get copyWith => __$DetectionLogEntryCopyWithImpl<_DetectionLogEntry>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DetectionLogEntry&&(identical(other.block, block) || other.block == block)&&(identical(other.keyType, keyType) || other.keyType == keyType)&&(identical(other.isNested, isNested) || other.isNested == isNested)&&const DeepCollectionEquality().equals(other.uid, uid)&&(identical(other.nt, nt) || other.nt == nt)&&(identical(other.nr, nr) || other.nr == nr)&&(identical(other.ar, ar) || other.ar == ar));
}


@override
int get hashCode {
    return Object.hash(runtimeType,block,keyType,isNested,const DeepCollectionEquality().hash(uid),nt,nr,ar);
}

@override
String toString() {
    return 'DetectionLogEntry(block: $block, keyType: $keyType, isNested: $isNested, uid: $uid, nt: $nt, nr: $nr, ar: $ar)';
}


}

/// @nodoc
abstract mixin class _$DetectionLogEntryCopyWith<$Res> implements $DetectionLogEntryCopyWith<$Res> {
  factory _$DetectionLogEntryCopyWith(_DetectionLogEntry value, $Res Function(_DetectionLogEntry) _then) = __$DetectionLogEntryCopyWithImpl;
@override @useResult
$Res call({
 int block, KeyType keyType, bool isNested, Uint8List uid, int nt, int nr, int ar
});




}
/// @nodoc
class __$DetectionLogEntryCopyWithImpl<$Res>
    implements _$DetectionLogEntryCopyWith<$Res> {
  __$DetectionLogEntryCopyWithImpl(this._self, this._then);

  final _DetectionLogEntry _self;
  final $Res Function(_DetectionLogEntry) _then;

/// Create a copy of DetectionLogEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? block = null,Object? keyType = null,Object? isNested = null,Object? uid = null,Object? nt = null,Object? nr = null,Object? ar = null,}) {
  return _then(_DetectionLogEntry(
block: null == block ? _self.block : block // ignore: cast_nullable_to_non_nullable
as int,keyType: null == keyType ? _self.keyType : keyType // ignore: cast_nullable_to_non_nullable
as KeyType,isNested: null == isNested ? _self.isNested : isNested // ignore: cast_nullable_to_non_nullable
as bool,uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as Uint8List,nt: null == nt ? _self.nt : nt // ignore: cast_nullable_to_non_nullable
as int,nr: null == nr ? _self.nr : nr // ignore: cast_nullable_to_non_nullable
as int,ar: null == ar ? _self.ar : ar // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
