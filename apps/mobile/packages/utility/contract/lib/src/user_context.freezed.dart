// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_context.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserContext {

/// What the user wants to be called: the name they typed, or the
/// placeholder emotely picked for them. Omitted from the wire when
/// there is none. At most [maxDisplayNameLength] code points
/// (`runes.length`) after `trim()`, with no control characters, or the
/// agent ignores the whole context.
@JsonKey(includeIfNull: false) String? get displayName;/// True when `displayName` is that placeholder, not a real name.
 bool get nameIsPlaceholder;/// The locale the app shows, as it resolved it against the ones it
/// ships — never the device's own list — so the companion asks and
/// writes the entry in the language on screen (#228). A language tag
/// on the wire; omitted when there is none, and the agent speaks
/// English.
@JsonKey(includeIfNull: false)@LanguageTagConverter() Locale? get locale;
/// Create a copy of UserContext
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserContextCopyWith<UserContext> get copyWith => _$UserContextCopyWithImpl<UserContext>(this as UserContext, _$identity);

  /// Serializes this UserContext to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as UserContext;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserContext&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.nameIsPlaceholder, _this.nameIsPlaceholder) || other.nameIsPlaceholder == _this.nameIsPlaceholder)&&(identical(other.locale, _this.locale) || other.locale == _this.locale));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as UserContext;
  return Object.hash(runtimeType,_this.displayName,_this.nameIsPlaceholder,_this.locale);
}



}

/// @nodoc
abstract mixin class $UserContextCopyWith<$Res>  {
  factory $UserContextCopyWith(UserContext value, $Res Function(UserContext) _then) = _$UserContextCopyWithImpl;
@useResult
$Res call({
@JsonKey(includeIfNull: false) String? displayName, bool nameIsPlaceholder,@JsonKey(includeIfNull: false)@LanguageTagConverter() Locale? locale
});




}
/// @nodoc
class _$UserContextCopyWithImpl<$Res>
    implements $UserContextCopyWith<$Res> {
  _$UserContextCopyWithImpl(this._self, this._then);

  final UserContext _self;
  final $Res Function(UserContext) _then;

/// Create a copy of UserContext
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? displayName = freezed,Object? nameIsPlaceholder = null,Object? locale = freezed,}) {
  return _then(UserContext(
displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,nameIsPlaceholder: null == nameIsPlaceholder ? _self.nameIsPlaceholder : nameIsPlaceholder // ignore: cast_nullable_to_non_nullable
as bool,locale: freezed == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as Locale?,
  ));
}

}


/// Adds pattern-matching-related methods to [UserContext].
extension UserContextPatterns on UserContext {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserContext value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserContext() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserContext value)  $default,){
final _that = this;
switch (_that) {
case _UserContext():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserContext value)?  $default,){
final _that = this;
switch (_that) {
case _UserContext() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(includeIfNull: false)  String? displayName,  bool nameIsPlaceholder, @JsonKey(includeIfNull: false)@LanguageTagConverter()  Locale? locale)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserContext() when $default != null:
return $default(_that.displayName,_that.nameIsPlaceholder,_that.locale);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(includeIfNull: false)  String? displayName,  bool nameIsPlaceholder, @JsonKey(includeIfNull: false)@LanguageTagConverter()  Locale? locale)  $default,) {final _that = this;
switch (_that) {
case _UserContext():
return $default(_that.displayName,_that.nameIsPlaceholder,_that.locale);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(includeIfNull: false)  String? displayName,  bool nameIsPlaceholder, @JsonKey(includeIfNull: false)@LanguageTagConverter()  Locale? locale)?  $default,) {final _that = this;
switch (_that) {
case _UserContext() when $default != null:
return $default(_that.displayName,_that.nameIsPlaceholder,_that.locale);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserContext implements UserContext {
  const _UserContext({@JsonKey(includeIfNull: false) this.displayName, this.nameIsPlaceholder = false, @JsonKey(includeIfNull: false)@LanguageTagConverter() this.locale});
  factory _UserContext.fromJson(Map<String, dynamic> json) => _$UserContextFromJson(json);

/// What the user wants to be called: the name they typed, or the
/// placeholder emotely picked for them. Omitted from the wire when
/// there is none. At most [maxDisplayNameLength] code points
/// (`runes.length`) after `trim()`, with no control characters, or the
/// agent ignores the whole context.
@override@JsonKey(includeIfNull: false) final  String? displayName;
/// True when `displayName` is that placeholder, not a real name.
@override@JsonKey() final  bool nameIsPlaceholder;
/// The locale the app shows, as it resolved it against the ones it
/// ships — never the device's own list — so the companion asks and
/// writes the entry in the language on screen (#228). A language tag
/// on the wire; omitted when there is none, and the agent speaks
/// English.
@override@JsonKey(includeIfNull: false)@LanguageTagConverter() final  Locale? locale;

/// Create a copy of UserContext
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserContextCopyWith<_UserContext> get copyWith => __$UserContextCopyWithImpl<_UserContext>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserContextToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserContext&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.nameIsPlaceholder, nameIsPlaceholder) || other.nameIsPlaceholder == nameIsPlaceholder)&&(identical(other.locale, locale) || other.locale == locale));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,displayName,nameIsPlaceholder,locale);
}



}

/// @nodoc
abstract mixin class _$UserContextCopyWith<$Res> implements $UserContextCopyWith<$Res> {
  factory _$UserContextCopyWith(_UserContext value, $Res Function(_UserContext) _then) = __$UserContextCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(includeIfNull: false) String? displayName, bool nameIsPlaceholder,@JsonKey(includeIfNull: false)@LanguageTagConverter() Locale? locale
});




}
/// @nodoc
class __$UserContextCopyWithImpl<$Res>
    implements _$UserContextCopyWith<$Res> {
  __$UserContextCopyWithImpl(this._self, this._then);

  final _UserContext _self;
  final $Res Function(_UserContext) _then;

/// Create a copy of UserContext
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? displayName = freezed,Object? nameIsPlaceholder = null,Object? locale = freezed,}) {
  return _then(_UserContext(
displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,nameIsPlaceholder: null == nameIsPlaceholder ? _self.nameIsPlaceholder : nameIsPlaceholder // ignore: cast_nullable_to_non_nullable
as bool,locale: freezed == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as Locale?,
  ));
}


}

// dart format on
