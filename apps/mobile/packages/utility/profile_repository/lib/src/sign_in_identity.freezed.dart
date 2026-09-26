// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sign_in_identity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SignInIdentity {

 String? get email; SignInVia? get method;
/// Create a copy of SignInIdentity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SignInIdentityCopyWith<SignInIdentity> get copyWith => _$SignInIdentityCopyWithImpl<SignInIdentity>(this as SignInIdentity, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SignInIdentity;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SignInIdentity&&(identical(other.email, _this.email) || other.email == _this.email)&&(identical(other.method, _this.method) || other.method == _this.method));
}


@override
int get hashCode {
  final _this = this as SignInIdentity;
  return Object.hash(runtimeType,_this.email,_this.method);
}



}

/// @nodoc
abstract mixin class $SignInIdentityCopyWith<$Res>  {
  factory $SignInIdentityCopyWith(SignInIdentity value, $Res Function(SignInIdentity) _then) = _$SignInIdentityCopyWithImpl;
@useResult
$Res call({
 String? email, SignInVia? method
});




}
/// @nodoc
class _$SignInIdentityCopyWithImpl<$Res>
    implements $SignInIdentityCopyWith<$Res> {
  _$SignInIdentityCopyWithImpl(this._self, this._then);

  final SignInIdentity _self;
  final $Res Function(SignInIdentity) _then;

/// Create a copy of SignInIdentity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? email = freezed,Object? method = freezed,}) {
  return _then(SignInIdentity(
email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,method: freezed == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as SignInVia?,
  ));
}

}


/// Adds pattern-matching-related methods to [SignInIdentity].
extension SignInIdentityPatterns on SignInIdentity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SignInIdentity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SignInIdentity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SignInIdentity value)  $default,){
final _that = this;
switch (_that) {
case _SignInIdentity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SignInIdentity value)?  $default,){
final _that = this;
switch (_that) {
case _SignInIdentity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? email,  SignInVia? method)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SignInIdentity() when $default != null:
return $default(_that.email,_that.method);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? email,  SignInVia? method)  $default,) {final _that = this;
switch (_that) {
case _SignInIdentity():
return $default(_that.email,_that.method);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? email,  SignInVia? method)?  $default,) {final _that = this;
switch (_that) {
case _SignInIdentity() when $default != null:
return $default(_that.email,_that.method);case _:
  return null;

}
}

}

/// @nodoc


class _SignInIdentity implements SignInIdentity {
  const _SignInIdentity({this.email, this.method});
  

@override final  String? email;
@override final  SignInVia? method;

/// Create a copy of SignInIdentity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SignInIdentityCopyWith<_SignInIdentity> get copyWith => __$SignInIdentityCopyWithImpl<_SignInIdentity>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SignInIdentity&&(identical(other.email, email) || other.email == email)&&(identical(other.method, method) || other.method == method));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email,method);
}



}

/// @nodoc
abstract mixin class _$SignInIdentityCopyWith<$Res> implements $SignInIdentityCopyWith<$Res> {
  factory _$SignInIdentityCopyWith(_SignInIdentity value, $Res Function(_SignInIdentity) _then) = __$SignInIdentityCopyWithImpl;
@override @useResult
$Res call({
 String? email, SignInVia? method
});




}
/// @nodoc
class __$SignInIdentityCopyWithImpl<$Res>
    implements _$SignInIdentityCopyWith<$Res> {
  __$SignInIdentityCopyWithImpl(this._self, this._then);

  final _SignInIdentity _self;
  final $Res Function(_SignInIdentity) _then;

/// Create a copy of SignInIdentity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? email = freezed,Object? method = freezed,}) {
  return _then(_SignInIdentity(
email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,method: freezed == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as SignInVia?,
  ));
}


}

// dart format on
