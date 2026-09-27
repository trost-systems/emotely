// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProfileEvent {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileEvent);
}


@override
int get hashCode => runtimeType.hashCode;



}

/// @nodoc
class $ProfileEventCopyWith<$Res>  {
$ProfileEventCopyWith(ProfileEvent _, $Res Function(ProfileEvent) __);
}


/// Adds pattern-matching-related methods to [ProfileEvent].
extension ProfileEventPatterns on ProfileEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ProfileLoaded value)?  loaded,TResult Function( ProfileNameSubmitted value)?  nameSubmitted,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ProfileLoaded() when loaded != null:
return loaded(_that);case ProfileNameSubmitted() when nameSubmitted != null:
return nameSubmitted(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ProfileLoaded value)  loaded,required TResult Function( ProfileNameSubmitted value)  nameSubmitted,}){
final _that = this;
switch (_that) {
case ProfileLoaded():
return loaded(_that);case ProfileNameSubmitted():
return nameSubmitted(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ProfileLoaded value)?  loaded,TResult? Function( ProfileNameSubmitted value)?  nameSubmitted,}){
final _that = this;
switch (_that) {
case ProfileLoaded() when loaded != null:
return loaded(_that);case ProfileNameSubmitted() when nameSubmitted != null:
return nameSubmitted(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  loaded,TResult Function( String raw)?  nameSubmitted,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ProfileLoaded() when loaded != null:
return loaded();case ProfileNameSubmitted() when nameSubmitted != null:
return nameSubmitted(_that.raw);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  loaded,required TResult Function( String raw)  nameSubmitted,}) {final _that = this;
switch (_that) {
case ProfileLoaded():
return loaded();case ProfileNameSubmitted():
return nameSubmitted(_that.raw);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  loaded,TResult? Function( String raw)?  nameSubmitted,}) {final _that = this;
switch (_that) {
case ProfileLoaded() when loaded != null:
return loaded();case ProfileNameSubmitted() when nameSubmitted != null:
return nameSubmitted(_that.raw);case _:
  return null;

}
}

}

/// @nodoc


class ProfileLoaded implements ProfileEvent {
  const ProfileLoaded();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileLoaded);
}


@override
int get hashCode => runtimeType.hashCode;



}




/// @nodoc


class ProfileNameSubmitted implements ProfileEvent {
  const ProfileNameSubmitted(this.raw);
  

 final  String raw;

/// Create a copy of ProfileEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileNameSubmittedCopyWith<ProfileNameSubmitted> get copyWith => _$ProfileNameSubmittedCopyWithImpl<ProfileNameSubmitted>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileNameSubmitted&&(identical(other.raw, raw) || other.raw == raw));
}


@override
int get hashCode {
    return Object.hash(runtimeType,raw);
}



}

/// @nodoc
abstract mixin class $ProfileNameSubmittedCopyWith<$Res> implements $ProfileEventCopyWith<$Res> {
  factory $ProfileNameSubmittedCopyWith(ProfileNameSubmitted value, $Res Function(ProfileNameSubmitted) _then) = _$ProfileNameSubmittedCopyWithImpl;
@useResult
$Res call({
 String raw
});




}
/// @nodoc
class _$ProfileNameSubmittedCopyWithImpl<$Res>
    implements $ProfileNameSubmittedCopyWith<$Res> {
  _$ProfileNameSubmittedCopyWithImpl(this._self, this._then);

  final ProfileNameSubmitted _self;
  final $Res Function(ProfileNameSubmitted) _then;

/// Create a copy of ProfileEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? raw = null,}) {
  return _then(ProfileNameSubmitted(
null == raw ? _self.raw : raw // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$ProfileState {

 ProfileStatus get status;/// The name as saved; none until the user has one.
 Profile? get profile;/// Who is signed in and how; none only while nobody is.
 SignInIdentity? get identity;/// A new name is on its way to the server.
 bool get saving;/// The last thing to tell the user, and how many have been told, so
/// the same notice twice in a row is still told twice.
 ProfileNotice? get notice; int get noticeCount;
/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileStateCopyWith<ProfileState> get copyWith => _$ProfileStateCopyWithImpl<ProfileState>(this as ProfileState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ProfileState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileState&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.profile, _this.profile) || other.profile == _this.profile)&&(identical(other.identity, _this.identity) || other.identity == _this.identity)&&(identical(other.saving, _this.saving) || other.saving == _this.saving)&&(identical(other.notice, _this.notice) || other.notice == _this.notice)&&(identical(other.noticeCount, _this.noticeCount) || other.noticeCount == _this.noticeCount));
}


@override
int get hashCode {
  final _this = this as ProfileState;
  return Object.hash(runtimeType,_this.status,_this.profile,_this.identity,_this.saving,_this.notice,_this.noticeCount);
}



}

/// @nodoc
abstract mixin class $ProfileStateCopyWith<$Res>  {
  factory $ProfileStateCopyWith(ProfileState value, $Res Function(ProfileState) _then) = _$ProfileStateCopyWithImpl;
@useResult
$Res call({
 ProfileStatus status, Profile? profile, SignInIdentity? identity, bool saving, ProfileNotice? notice, int noticeCount
});


$ProfileCopyWith<$Res>? get profile;$SignInIdentityCopyWith<$Res>? get identity;

}
/// @nodoc
class _$ProfileStateCopyWithImpl<$Res>
    implements $ProfileStateCopyWith<$Res> {
  _$ProfileStateCopyWithImpl(this._self, this._then);

  final ProfileState _self;
  final $Res Function(ProfileState) _then;

/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? profile = freezed,Object? identity = freezed,Object? saving = null,Object? notice = freezed,Object? noticeCount = null,}) {
  return _then(ProfileState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ProfileStatus,profile: freezed == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as Profile?,identity: freezed == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as SignInIdentity?,saving: null == saving ? _self.saving : saving // ignore: cast_nullable_to_non_nullable
as bool,notice: freezed == notice ? _self.notice : notice // ignore: cast_nullable_to_non_nullable
as ProfileNotice?,noticeCount: null == noticeCount ? _self.noticeCount : noticeCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfileCopyWith<$Res>? get profile {
    if (_self.profile == null) {
    return null;
  }

  return $ProfileCopyWith<$Res>(_self.profile!, (value) {
    return _then(_self.copyWith(profile: value));
  });
}/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SignInIdentityCopyWith<$Res>? get identity {
    if (_self.identity == null) {
    return null;
  }

  return $SignInIdentityCopyWith<$Res>(_self.identity!, (value) {
    return _then(_self.copyWith(identity: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProfileState].
extension ProfileStatePatterns on ProfileState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileState value)  $default,){
final _that = this;
switch (_that) {
case _ProfileState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileState value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ProfileStatus status,  Profile? profile,  SignInIdentity? identity,  bool saving,  ProfileNotice? notice,  int noticeCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileState() when $default != null:
return $default(_that.status,_that.profile,_that.identity,_that.saving,_that.notice,_that.noticeCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ProfileStatus status,  Profile? profile,  SignInIdentity? identity,  bool saving,  ProfileNotice? notice,  int noticeCount)  $default,) {final _that = this;
switch (_that) {
case _ProfileState():
return $default(_that.status,_that.profile,_that.identity,_that.saving,_that.notice,_that.noticeCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ProfileStatus status,  Profile? profile,  SignInIdentity? identity,  bool saving,  ProfileNotice? notice,  int noticeCount)?  $default,) {final _that = this;
switch (_that) {
case _ProfileState() when $default != null:
return $default(_that.status,_that.profile,_that.identity,_that.saving,_that.notice,_that.noticeCount);case _:
  return null;

}
}

}

/// @nodoc


class _ProfileState implements ProfileState {
  const _ProfileState({this.status = ProfileStatus.loading, this.profile, this.identity, this.saving = false, this.notice, this.noticeCount = 0});
  

@override@JsonKey() final  ProfileStatus status;
/// The name as saved; none until the user has one.
@override final  Profile? profile;
/// Who is signed in and how; none only while nobody is.
@override final  SignInIdentity? identity;
/// A new name is on its way to the server.
@override@JsonKey() final  bool saving;
/// The last thing to tell the user, and how many have been told, so
/// the same notice twice in a row is still told twice.
@override final  ProfileNotice? notice;
@override@JsonKey() final  int noticeCount;

/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileStateCopyWith<_ProfileState> get copyWith => __$ProfileStateCopyWithImpl<_ProfileState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileState&&(identical(other.status, status) || other.status == status)&&(identical(other.profile, profile) || other.profile == profile)&&(identical(other.identity, identity) || other.identity == identity)&&(identical(other.saving, saving) || other.saving == saving)&&(identical(other.notice, notice) || other.notice == notice)&&(identical(other.noticeCount, noticeCount) || other.noticeCount == noticeCount));
}


@override
int get hashCode {
    return Object.hash(runtimeType,status,profile,identity,saving,notice,noticeCount);
}



}

/// @nodoc
abstract mixin class _$ProfileStateCopyWith<$Res> implements $ProfileStateCopyWith<$Res> {
  factory _$ProfileStateCopyWith(_ProfileState value, $Res Function(_ProfileState) _then) = __$ProfileStateCopyWithImpl;
@override @useResult
$Res call({
 ProfileStatus status, Profile? profile, SignInIdentity? identity, bool saving, ProfileNotice? notice, int noticeCount
});


@override $ProfileCopyWith<$Res>? get profile;@override $SignInIdentityCopyWith<$Res>? get identity;

}
/// @nodoc
class __$ProfileStateCopyWithImpl<$Res>
    implements _$ProfileStateCopyWith<$Res> {
  __$ProfileStateCopyWithImpl(this._self, this._then);

  final _ProfileState _self;
  final $Res Function(_ProfileState) _then;

/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? profile = freezed,Object? identity = freezed,Object? saving = null,Object? notice = freezed,Object? noticeCount = null,}) {
  return _then(_ProfileState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ProfileStatus,profile: freezed == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as Profile?,identity: freezed == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as SignInIdentity?,saving: null == saving ? _self.saving : saving // ignore: cast_nullable_to_non_nullable
as bool,notice: freezed == notice ? _self.notice : notice // ignore: cast_nullable_to_non_nullable
as ProfileNotice?,noticeCount: null == noticeCount ? _self.noticeCount : noticeCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfileCopyWith<$Res>? get profile {
    if (_self.profile == null) {
    return null;
  }

  return $ProfileCopyWith<$Res>(_self.profile!, (value) {
    return _then(_self.copyWith(profile: value));
  });
}/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SignInIdentityCopyWith<$Res>? get identity {
    if (_self.identity == null) {
    return null;
  }

  return $SignInIdentityCopyWith<$Res>(_self.identity!, (value) {
    return _then(_self.copyWith(identity: value));
  });
}
}

// dart format on
