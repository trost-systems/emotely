// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'config_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ConfigEvent {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConfigEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ConfigEvent()';
}


}

/// @nodoc
class $ConfigEventCopyWith<$Res>  {
$ConfigEventCopyWith(ConfigEvent _, $Res Function(ConfigEvent) __);
}


/// Adds pattern-matching-related methods to [ConfigEvent].
extension ConfigEventPatterns on ConfigEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ConfigLoaded value)?  loaded,TResult Function( ConfigUpdateRequested value)?  updateRequested,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ConfigLoaded() when loaded != null:
return loaded(_that);case ConfigUpdateRequested() when updateRequested != null:
return updateRequested(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ConfigLoaded value)  loaded,required TResult Function( ConfigUpdateRequested value)  updateRequested,}){
final _that = this;
switch (_that) {
case ConfigLoaded():
return loaded(_that);case ConfigUpdateRequested():
return updateRequested(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ConfigLoaded value)?  loaded,TResult? Function( ConfigUpdateRequested value)?  updateRequested,}){
final _that = this;
switch (_that) {
case ConfigLoaded() when loaded != null:
return loaded(_that);case ConfigUpdateRequested() when updateRequested != null:
return updateRequested(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  loaded,TResult Function()?  updateRequested,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ConfigLoaded() when loaded != null:
return loaded();case ConfigUpdateRequested() when updateRequested != null:
return updateRequested();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  loaded,required TResult Function()  updateRequested,}) {final _that = this;
switch (_that) {
case ConfigLoaded():
return loaded();case ConfigUpdateRequested():
return updateRequested();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  loaded,TResult? Function()?  updateRequested,}) {final _that = this;
switch (_that) {
case ConfigLoaded() when loaded != null:
return loaded();case ConfigUpdateRequested() when updateRequested != null:
return updateRequested();case _:
  return null;

}
}

}

/// @nodoc


class ConfigLoaded implements ConfigEvent {
  const ConfigLoaded();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConfigLoaded);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ConfigEvent.loaded()';
}


}




/// @nodoc


class ConfigUpdateRequested implements ConfigEvent {
  const ConfigUpdateRequested();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConfigUpdateRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ConfigEvent.updateRequested()';
}


}




/// @nodoc
mixin _$ConfigState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConfigState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ConfigState()';
}


}

/// @nodoc
class $ConfigStateCopyWith<$Res>  {
$ConfigStateCopyWith(ConfigState _, $Res Function(ConfigState) __);
}


/// Adds pattern-matching-related methods to [ConfigState].
extension ConfigStatePatterns on ConfigState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ConfigUnknown value)?  unknown,TResult Function( ConfigReady value)?  ready,TResult Function( ConfigUpdateRequired value)?  updateRequired,TResult Function( ConfigFailure value)?  failure,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ConfigUnknown() when unknown != null:
return unknown(_that);case ConfigReady() when ready != null:
return ready(_that);case ConfigUpdateRequired() when updateRequired != null:
return updateRequired(_that);case ConfigFailure() when failure != null:
return failure(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ConfigUnknown value)  unknown,required TResult Function( ConfigReady value)  ready,required TResult Function( ConfigUpdateRequired value)  updateRequired,required TResult Function( ConfigFailure value)  failure,}){
final _that = this;
switch (_that) {
case ConfigUnknown():
return unknown(_that);case ConfigReady():
return ready(_that);case ConfigUpdateRequired():
return updateRequired(_that);case ConfigFailure():
return failure(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ConfigUnknown value)?  unknown,TResult? Function( ConfigReady value)?  ready,TResult? Function( ConfigUpdateRequired value)?  updateRequired,TResult? Function( ConfigFailure value)?  failure,}){
final _that = this;
switch (_that) {
case ConfigUnknown() when unknown != null:
return unknown(_that);case ConfigReady() when ready != null:
return ready(_that);case ConfigUpdateRequired() when updateRequired != null:
return updateRequired(_that);case ConfigFailure() when failure != null:
return failure(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  unknown,TResult Function()?  ready,TResult Function( String minAppVersion,  String storeUrl)?  updateRequired,TResult Function( ConfigProblem problem)?  failure,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ConfigUnknown() when unknown != null:
return unknown();case ConfigReady() when ready != null:
return ready();case ConfigUpdateRequired() when updateRequired != null:
return updateRequired(_that.minAppVersion,_that.storeUrl);case ConfigFailure() when failure != null:
return failure(_that.problem);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  unknown,required TResult Function()  ready,required TResult Function( String minAppVersion,  String storeUrl)  updateRequired,required TResult Function( ConfigProblem problem)  failure,}) {final _that = this;
switch (_that) {
case ConfigUnknown():
return unknown();case ConfigReady():
return ready();case ConfigUpdateRequired():
return updateRequired(_that.minAppVersion,_that.storeUrl);case ConfigFailure():
return failure(_that.problem);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  unknown,TResult? Function()?  ready,TResult? Function( String minAppVersion,  String storeUrl)?  updateRequired,TResult? Function( ConfigProblem problem)?  failure,}) {final _that = this;
switch (_that) {
case ConfigUnknown() when unknown != null:
return unknown();case ConfigReady() when ready != null:
return ready();case ConfigUpdateRequired() when updateRequired != null:
return updateRequired(_that.minAppVersion,_that.storeUrl);case ConfigFailure() when failure != null:
return failure(_that.problem);case _:
  return null;

}
}

}

/// @nodoc


class ConfigUnknown implements ConfigState {
  const ConfigUnknown();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConfigUnknown);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ConfigState.unknown()';
}


}




/// @nodoc


class ConfigReady implements ConfigState {
  const ConfigReady();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConfigReady);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ConfigState.ready()';
}


}




/// @nodoc


class ConfigUpdateRequired implements ConfigState {
  const ConfigUpdateRequired({required this.minAppVersion, required this.storeUrl});
  

 final  String minAppVersion;
 final  String storeUrl;

/// Create a copy of ConfigState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConfigUpdateRequiredCopyWith<ConfigUpdateRequired> get copyWith => _$ConfigUpdateRequiredCopyWithImpl<ConfigUpdateRequired>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConfigUpdateRequired&&(identical(other.minAppVersion, minAppVersion) || other.minAppVersion == minAppVersion)&&(identical(other.storeUrl, storeUrl) || other.storeUrl == storeUrl));
}


@override
int get hashCode {
    return Object.hash(runtimeType,minAppVersion,storeUrl);
}

@override
String toString() {
    return 'ConfigState.updateRequired(minAppVersion: $minAppVersion, storeUrl: $storeUrl)';
}


}

/// @nodoc
abstract mixin class $ConfigUpdateRequiredCopyWith<$Res> implements $ConfigStateCopyWith<$Res> {
  factory $ConfigUpdateRequiredCopyWith(ConfigUpdateRequired value, $Res Function(ConfigUpdateRequired) _then) = _$ConfigUpdateRequiredCopyWithImpl;
@useResult
$Res call({
 String minAppVersion, String storeUrl
});




}
/// @nodoc
class _$ConfigUpdateRequiredCopyWithImpl<$Res>
    implements $ConfigUpdateRequiredCopyWith<$Res> {
  _$ConfigUpdateRequiredCopyWithImpl(this._self, this._then);

  final ConfigUpdateRequired _self;
  final $Res Function(ConfigUpdateRequired) _then;

/// Create a copy of ConfigState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? minAppVersion = null,Object? storeUrl = null,}) {
  return _then(ConfigUpdateRequired(
minAppVersion: null == minAppVersion ? _self.minAppVersion : minAppVersion // ignore: cast_nullable_to_non_nullable
as String,storeUrl: null == storeUrl ? _self.storeUrl : storeUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ConfigFailure implements ConfigState {
  const ConfigFailure({required this.problem});
  

 final  ConfigProblem problem;

/// Create a copy of ConfigState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConfigFailureCopyWith<ConfigFailure> get copyWith => _$ConfigFailureCopyWithImpl<ConfigFailure>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConfigFailure&&(identical(other.problem, problem) || other.problem == problem));
}


@override
int get hashCode {
    return Object.hash(runtimeType,problem);
}

@override
String toString() {
    return 'ConfigState.failure(problem: $problem)';
}


}

/// @nodoc
abstract mixin class $ConfigFailureCopyWith<$Res> implements $ConfigStateCopyWith<$Res> {
  factory $ConfigFailureCopyWith(ConfigFailure value, $Res Function(ConfigFailure) _then) = _$ConfigFailureCopyWithImpl;
@useResult
$Res call({
 ConfigProblem problem
});




}
/// @nodoc
class _$ConfigFailureCopyWithImpl<$Res>
    implements $ConfigFailureCopyWith<$Res> {
  _$ConfigFailureCopyWithImpl(this._self, this._then);

  final ConfigFailure _self;
  final $Res Function(ConfigFailure) _then;

/// Create a copy of ConfigState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? problem = null,}) {
  return _then(ConfigFailure(
problem: null == problem ? _self.problem : problem // ignore: cast_nullable_to_non_nullable
as ConfigProblem,
  ));
}


}

// dart format on
