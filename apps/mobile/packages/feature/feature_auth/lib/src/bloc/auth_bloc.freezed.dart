// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AuthEvent {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthEvent);
}


@override
int get hashCode => runtimeType.hashCode;



}

/// @nodoc
class $AuthEventCopyWith<$Res>  {
$AuthEventCopyWith(AuthEvent _, $Res Function(AuthEvent) __);
}


/// Adds pattern-matching-related methods to [AuthEvent].
extension AuthEventPatterns on AuthEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AuthEmailSubmitted value)?  emailSubmitted,TResult Function( AuthCodeSubmitted value)?  codeSubmitted,TResult Function( AuthPasswordSubmitted value)?  passwordSubmitted,TResult Function( AuthProviderSelected value)?  providerSelected,TResult Function( AuthEmailChangeRequested value)?  emailChangeRequested,TResult Function( AuthSignOutRequested value)?  signOutRequested,TResult Function( AuthSessionChanged value)?  sessionChanged,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AuthEmailSubmitted() when emailSubmitted != null:
return emailSubmitted(_that);case AuthCodeSubmitted() when codeSubmitted != null:
return codeSubmitted(_that);case AuthPasswordSubmitted() when passwordSubmitted != null:
return passwordSubmitted(_that);case AuthProviderSelected() when providerSelected != null:
return providerSelected(_that);case AuthEmailChangeRequested() when emailChangeRequested != null:
return emailChangeRequested(_that);case AuthSignOutRequested() when signOutRequested != null:
return signOutRequested(_that);case AuthSessionChanged() when sessionChanged != null:
return sessionChanged(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AuthEmailSubmitted value)  emailSubmitted,required TResult Function( AuthCodeSubmitted value)  codeSubmitted,required TResult Function( AuthPasswordSubmitted value)  passwordSubmitted,required TResult Function( AuthProviderSelected value)  providerSelected,required TResult Function( AuthEmailChangeRequested value)  emailChangeRequested,required TResult Function( AuthSignOutRequested value)  signOutRequested,required TResult Function( AuthSessionChanged value)  sessionChanged,}){
final _that = this;
switch (_that) {
case AuthEmailSubmitted():
return emailSubmitted(_that);case AuthCodeSubmitted():
return codeSubmitted(_that);case AuthPasswordSubmitted():
return passwordSubmitted(_that);case AuthProviderSelected():
return providerSelected(_that);case AuthEmailChangeRequested():
return emailChangeRequested(_that);case AuthSignOutRequested():
return signOutRequested(_that);case AuthSessionChanged():
return sessionChanged(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AuthEmailSubmitted value)?  emailSubmitted,TResult? Function( AuthCodeSubmitted value)?  codeSubmitted,TResult? Function( AuthPasswordSubmitted value)?  passwordSubmitted,TResult? Function( AuthProviderSelected value)?  providerSelected,TResult? Function( AuthEmailChangeRequested value)?  emailChangeRequested,TResult? Function( AuthSignOutRequested value)?  signOutRequested,TResult? Function( AuthSessionChanged value)?  sessionChanged,}){
final _that = this;
switch (_that) {
case AuthEmailSubmitted() when emailSubmitted != null:
return emailSubmitted(_that);case AuthCodeSubmitted() when codeSubmitted != null:
return codeSubmitted(_that);case AuthPasswordSubmitted() when passwordSubmitted != null:
return passwordSubmitted(_that);case AuthProviderSelected() when providerSelected != null:
return providerSelected(_that);case AuthEmailChangeRequested() when emailChangeRequested != null:
return emailChangeRequested(_that);case AuthSignOutRequested() when signOutRequested != null:
return signOutRequested(_that);case AuthSessionChanged() when sessionChanged != null:
return sessionChanged(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String email)?  emailSubmitted,TResult Function( String code)?  codeSubmitted,TResult Function( String password)?  passwordSubmitted,TResult Function( IdentityProvider provider)?  providerSelected,TResult Function()?  emailChangeRequested,TResult Function()?  signOutRequested,TResult Function( String? userId,  SignInIdentity? identity)?  sessionChanged,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AuthEmailSubmitted() when emailSubmitted != null:
return emailSubmitted(_that.email);case AuthCodeSubmitted() when codeSubmitted != null:
return codeSubmitted(_that.code);case AuthPasswordSubmitted() when passwordSubmitted != null:
return passwordSubmitted(_that.password);case AuthProviderSelected() when providerSelected != null:
return providerSelected(_that.provider);case AuthEmailChangeRequested() when emailChangeRequested != null:
return emailChangeRequested();case AuthSignOutRequested() when signOutRequested != null:
return signOutRequested();case AuthSessionChanged() when sessionChanged != null:
return sessionChanged(_that.userId,_that.identity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String email)  emailSubmitted,required TResult Function( String code)  codeSubmitted,required TResult Function( String password)  passwordSubmitted,required TResult Function( IdentityProvider provider)  providerSelected,required TResult Function()  emailChangeRequested,required TResult Function()  signOutRequested,required TResult Function( String? userId,  SignInIdentity? identity)  sessionChanged,}) {final _that = this;
switch (_that) {
case AuthEmailSubmitted():
return emailSubmitted(_that.email);case AuthCodeSubmitted():
return codeSubmitted(_that.code);case AuthPasswordSubmitted():
return passwordSubmitted(_that.password);case AuthProviderSelected():
return providerSelected(_that.provider);case AuthEmailChangeRequested():
return emailChangeRequested();case AuthSignOutRequested():
return signOutRequested();case AuthSessionChanged():
return sessionChanged(_that.userId,_that.identity);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String email)?  emailSubmitted,TResult? Function( String code)?  codeSubmitted,TResult? Function( String password)?  passwordSubmitted,TResult? Function( IdentityProvider provider)?  providerSelected,TResult? Function()?  emailChangeRequested,TResult? Function()?  signOutRequested,TResult? Function( String? userId,  SignInIdentity? identity)?  sessionChanged,}) {final _that = this;
switch (_that) {
case AuthEmailSubmitted() when emailSubmitted != null:
return emailSubmitted(_that.email);case AuthCodeSubmitted() when codeSubmitted != null:
return codeSubmitted(_that.code);case AuthPasswordSubmitted() when passwordSubmitted != null:
return passwordSubmitted(_that.password);case AuthProviderSelected() when providerSelected != null:
return providerSelected(_that.provider);case AuthEmailChangeRequested() when emailChangeRequested != null:
return emailChangeRequested();case AuthSignOutRequested() when signOutRequested != null:
return signOutRequested();case AuthSessionChanged() when sessionChanged != null:
return sessionChanged(_that.userId,_that.identity);case _:
  return null;

}
}

}

/// @nodoc


class AuthEmailSubmitted implements AuthEvent {
  const AuthEmailSubmitted(this.email);
  

 final  String email;

/// Create a copy of AuthEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthEmailSubmittedCopyWith<AuthEmailSubmitted> get copyWith => _$AuthEmailSubmittedCopyWithImpl<AuthEmailSubmitted>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthEmailSubmitted&&(identical(other.email, email) || other.email == email));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email);
}



}

/// @nodoc
abstract mixin class $AuthEmailSubmittedCopyWith<$Res> implements $AuthEventCopyWith<$Res> {
  factory $AuthEmailSubmittedCopyWith(AuthEmailSubmitted value, $Res Function(AuthEmailSubmitted) _then) = _$AuthEmailSubmittedCopyWithImpl;
@useResult
$Res call({
 String email
});




}
/// @nodoc
class _$AuthEmailSubmittedCopyWithImpl<$Res>
    implements $AuthEmailSubmittedCopyWith<$Res> {
  _$AuthEmailSubmittedCopyWithImpl(this._self, this._then);

  final AuthEmailSubmitted _self;
  final $Res Function(AuthEmailSubmitted) _then;

/// Create a copy of AuthEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,}) {
  return _then(AuthEmailSubmitted(
null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class AuthCodeSubmitted implements AuthEvent {
  const AuthCodeSubmitted(this.code);
  

 final  String code;

/// Create a copy of AuthEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthCodeSubmittedCopyWith<AuthCodeSubmitted> get copyWith => _$AuthCodeSubmittedCopyWithImpl<AuthCodeSubmitted>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthCodeSubmitted&&(identical(other.code, code) || other.code == code));
}


@override
int get hashCode {
    return Object.hash(runtimeType,code);
}



}

/// @nodoc
abstract mixin class $AuthCodeSubmittedCopyWith<$Res> implements $AuthEventCopyWith<$Res> {
  factory $AuthCodeSubmittedCopyWith(AuthCodeSubmitted value, $Res Function(AuthCodeSubmitted) _then) = _$AuthCodeSubmittedCopyWithImpl;
@useResult
$Res call({
 String code
});




}
/// @nodoc
class _$AuthCodeSubmittedCopyWithImpl<$Res>
    implements $AuthCodeSubmittedCopyWith<$Res> {
  _$AuthCodeSubmittedCopyWithImpl(this._self, this._then);

  final AuthCodeSubmitted _self;
  final $Res Function(AuthCodeSubmitted) _then;

/// Create a copy of AuthEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? code = null,}) {
  return _then(AuthCodeSubmitted(
null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class AuthPasswordSubmitted implements AuthEvent {
  const AuthPasswordSubmitted(this.password);
  

 final  String password;

/// Create a copy of AuthEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthPasswordSubmittedCopyWith<AuthPasswordSubmitted> get copyWith => _$AuthPasswordSubmittedCopyWithImpl<AuthPasswordSubmitted>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthPasswordSubmitted&&(identical(other.password, password) || other.password == password));
}


@override
int get hashCode {
    return Object.hash(runtimeType,password);
}



}

/// @nodoc
abstract mixin class $AuthPasswordSubmittedCopyWith<$Res> implements $AuthEventCopyWith<$Res> {
  factory $AuthPasswordSubmittedCopyWith(AuthPasswordSubmitted value, $Res Function(AuthPasswordSubmitted) _then) = _$AuthPasswordSubmittedCopyWithImpl;
@useResult
$Res call({
 String password
});




}
/// @nodoc
class _$AuthPasswordSubmittedCopyWithImpl<$Res>
    implements $AuthPasswordSubmittedCopyWith<$Res> {
  _$AuthPasswordSubmittedCopyWithImpl(this._self, this._then);

  final AuthPasswordSubmitted _self;
  final $Res Function(AuthPasswordSubmitted) _then;

/// Create a copy of AuthEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? password = null,}) {
  return _then(AuthPasswordSubmitted(
null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class AuthProviderSelected implements AuthEvent {
  const AuthProviderSelected(this.provider);
  

 final  IdentityProvider provider;

/// Create a copy of AuthEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthProviderSelectedCopyWith<AuthProviderSelected> get copyWith => _$AuthProviderSelectedCopyWithImpl<AuthProviderSelected>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthProviderSelected&&(identical(other.provider, provider) || other.provider == provider));
}


@override
int get hashCode {
    return Object.hash(runtimeType,provider);
}



}

/// @nodoc
abstract mixin class $AuthProviderSelectedCopyWith<$Res> implements $AuthEventCopyWith<$Res> {
  factory $AuthProviderSelectedCopyWith(AuthProviderSelected value, $Res Function(AuthProviderSelected) _then) = _$AuthProviderSelectedCopyWithImpl;
@useResult
$Res call({
 IdentityProvider provider
});




}
/// @nodoc
class _$AuthProviderSelectedCopyWithImpl<$Res>
    implements $AuthProviderSelectedCopyWith<$Res> {
  _$AuthProviderSelectedCopyWithImpl(this._self, this._then);

  final AuthProviderSelected _self;
  final $Res Function(AuthProviderSelected) _then;

/// Create a copy of AuthEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? provider = null,}) {
  return _then(AuthProviderSelected(
null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as IdentityProvider,
  ));
}


}

/// @nodoc


class AuthEmailChangeRequested implements AuthEvent {
  const AuthEmailChangeRequested();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthEmailChangeRequested);
}


@override
int get hashCode => runtimeType.hashCode;



}




/// @nodoc


class AuthSignOutRequested implements AuthEvent {
  const AuthSignOutRequested();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthSignOutRequested);
}


@override
int get hashCode => runtimeType.hashCode;



}




/// @nodoc


class AuthSessionChanged implements AuthEvent {
  const AuthSessionChanged(this.userId, this.identity);
  

 final  String? userId;
 final  SignInIdentity? identity;

/// Create a copy of AuthEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthSessionChangedCopyWith<AuthSessionChanged> get copyWith => _$AuthSessionChangedCopyWithImpl<AuthSessionChanged>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthSessionChanged&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.identity, identity) || other.identity == identity));
}


@override
int get hashCode {
    return Object.hash(runtimeType,userId,identity);
}



}

/// @nodoc
abstract mixin class $AuthSessionChangedCopyWith<$Res> implements $AuthEventCopyWith<$Res> {
  factory $AuthSessionChangedCopyWith(AuthSessionChanged value, $Res Function(AuthSessionChanged) _then) = _$AuthSessionChangedCopyWithImpl;
@useResult
$Res call({
 String? userId, SignInIdentity? identity
});


$SignInIdentityCopyWith<$Res>? get identity;

}
/// @nodoc
class _$AuthSessionChangedCopyWithImpl<$Res>
    implements $AuthSessionChangedCopyWith<$Res> {
  _$AuthSessionChangedCopyWithImpl(this._self, this._then);

  final AuthSessionChanged _self;
  final $Res Function(AuthSessionChanged) _then;

/// Create a copy of AuthEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? userId = freezed,Object? identity = freezed,}) {
  return _then(AuthSessionChanged(
freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String?,freezed == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as SignInIdentity?,
  ));
}

/// Create a copy of AuthEvent
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

/// @nodoc
mixin _$AuthState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthState);
}


@override
int get hashCode => runtimeType.hashCode;



}

/// @nodoc
class $AuthStateCopyWith<$Res>  {
$AuthStateCopyWith(AuthState _, $Res Function(AuthState) __);
}


/// Adds pattern-matching-related methods to [AuthState].
extension AuthStatePatterns on AuthState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AuthSignedOut value)?  signedOut,TResult Function( AuthRequestingCode value)?  requestingCode,TResult Function( AuthCodeSent value)?  codeSent,TResult Function( AuthVerifying value)?  verifying,TResult Function( AuthSigningInWith value)?  signingInWith,TResult Function( AuthPasswordRequired value)?  passwordRequired,TResult Function( AuthCheckingPassword value)?  checkingPassword,TResult Function( AuthSignedIn value)?  signedIn,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AuthSignedOut() when signedOut != null:
return signedOut(_that);case AuthRequestingCode() when requestingCode != null:
return requestingCode(_that);case AuthCodeSent() when codeSent != null:
return codeSent(_that);case AuthVerifying() when verifying != null:
return verifying(_that);case AuthSigningInWith() when signingInWith != null:
return signingInWith(_that);case AuthPasswordRequired() when passwordRequired != null:
return passwordRequired(_that);case AuthCheckingPassword() when checkingPassword != null:
return checkingPassword(_that);case AuthSignedIn() when signedIn != null:
return signedIn(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AuthSignedOut value)  signedOut,required TResult Function( AuthRequestingCode value)  requestingCode,required TResult Function( AuthCodeSent value)  codeSent,required TResult Function( AuthVerifying value)  verifying,required TResult Function( AuthSigningInWith value)  signingInWith,required TResult Function( AuthPasswordRequired value)  passwordRequired,required TResult Function( AuthCheckingPassword value)  checkingPassword,required TResult Function( AuthSignedIn value)  signedIn,}){
final _that = this;
switch (_that) {
case AuthSignedOut():
return signedOut(_that);case AuthRequestingCode():
return requestingCode(_that);case AuthCodeSent():
return codeSent(_that);case AuthVerifying():
return verifying(_that);case AuthSigningInWith():
return signingInWith(_that);case AuthPasswordRequired():
return passwordRequired(_that);case AuthCheckingPassword():
return checkingPassword(_that);case AuthSignedIn():
return signedIn(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AuthSignedOut value)?  signedOut,TResult? Function( AuthRequestingCode value)?  requestingCode,TResult? Function( AuthCodeSent value)?  codeSent,TResult? Function( AuthVerifying value)?  verifying,TResult? Function( AuthSigningInWith value)?  signingInWith,TResult? Function( AuthPasswordRequired value)?  passwordRequired,TResult? Function( AuthCheckingPassword value)?  checkingPassword,TResult? Function( AuthSignedIn value)?  signedIn,}){
final _that = this;
switch (_that) {
case AuthSignedOut() when signedOut != null:
return signedOut(_that);case AuthRequestingCode() when requestingCode != null:
return requestingCode(_that);case AuthCodeSent() when codeSent != null:
return codeSent(_that);case AuthVerifying() when verifying != null:
return verifying(_that);case AuthSigningInWith() when signingInWith != null:
return signingInWith(_that);case AuthPasswordRequired() when passwordRequired != null:
return passwordRequired(_that);case AuthCheckingPassword() when checkingPassword != null:
return checkingPassword(_that);case AuthSignedIn() when signedIn != null:
return signedIn(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String? error)?  signedOut,TResult Function( String email)?  requestingCode,TResult Function( String email,  String? error)?  codeSent,TResult Function( String email)?  verifying,TResult Function( IdentityProvider provider)?  signingInWith,TResult Function( String email,  String? error)?  passwordRequired,TResult Function( String email)?  checkingPassword,TResult Function( String userId,  SignInIdentity identity)?  signedIn,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AuthSignedOut() when signedOut != null:
return signedOut(_that.error);case AuthRequestingCode() when requestingCode != null:
return requestingCode(_that.email);case AuthCodeSent() when codeSent != null:
return codeSent(_that.email,_that.error);case AuthVerifying() when verifying != null:
return verifying(_that.email);case AuthSigningInWith() when signingInWith != null:
return signingInWith(_that.provider);case AuthPasswordRequired() when passwordRequired != null:
return passwordRequired(_that.email,_that.error);case AuthCheckingPassword() when checkingPassword != null:
return checkingPassword(_that.email);case AuthSignedIn() when signedIn != null:
return signedIn(_that.userId,_that.identity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String? error)  signedOut,required TResult Function( String email)  requestingCode,required TResult Function( String email,  String? error)  codeSent,required TResult Function( String email)  verifying,required TResult Function( IdentityProvider provider)  signingInWith,required TResult Function( String email,  String? error)  passwordRequired,required TResult Function( String email)  checkingPassword,required TResult Function( String userId,  SignInIdentity identity)  signedIn,}) {final _that = this;
switch (_that) {
case AuthSignedOut():
return signedOut(_that.error);case AuthRequestingCode():
return requestingCode(_that.email);case AuthCodeSent():
return codeSent(_that.email,_that.error);case AuthVerifying():
return verifying(_that.email);case AuthSigningInWith():
return signingInWith(_that.provider);case AuthPasswordRequired():
return passwordRequired(_that.email,_that.error);case AuthCheckingPassword():
return checkingPassword(_that.email);case AuthSignedIn():
return signedIn(_that.userId,_that.identity);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String? error)?  signedOut,TResult? Function( String email)?  requestingCode,TResult? Function( String email,  String? error)?  codeSent,TResult? Function( String email)?  verifying,TResult? Function( IdentityProvider provider)?  signingInWith,TResult? Function( String email,  String? error)?  passwordRequired,TResult? Function( String email)?  checkingPassword,TResult? Function( String userId,  SignInIdentity identity)?  signedIn,}) {final _that = this;
switch (_that) {
case AuthSignedOut() when signedOut != null:
return signedOut(_that.error);case AuthRequestingCode() when requestingCode != null:
return requestingCode(_that.email);case AuthCodeSent() when codeSent != null:
return codeSent(_that.email,_that.error);case AuthVerifying() when verifying != null:
return verifying(_that.email);case AuthSigningInWith() when signingInWith != null:
return signingInWith(_that.provider);case AuthPasswordRequired() when passwordRequired != null:
return passwordRequired(_that.email,_that.error);case AuthCheckingPassword() when checkingPassword != null:
return checkingPassword(_that.email);case AuthSignedIn() when signedIn != null:
return signedIn(_that.userId,_that.identity);case _:
  return null;

}
}

}

/// @nodoc


class AuthSignedOut implements AuthState {
  const AuthSignedOut({this.error});
  

 final  String? error;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthSignedOutCopyWith<AuthSignedOut> get copyWith => _$AuthSignedOutCopyWithImpl<AuthSignedOut>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthSignedOut&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hash(runtimeType,error);
}



}

/// @nodoc
abstract mixin class $AuthSignedOutCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory $AuthSignedOutCopyWith(AuthSignedOut value, $Res Function(AuthSignedOut) _then) = _$AuthSignedOutCopyWithImpl;
@useResult
$Res call({
 String? error
});




}
/// @nodoc
class _$AuthSignedOutCopyWithImpl<$Res>
    implements $AuthSignedOutCopyWith<$Res> {
  _$AuthSignedOutCopyWithImpl(this._self, this._then);

  final AuthSignedOut _self;
  final $Res Function(AuthSignedOut) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = freezed,}) {
  return _then(AuthSignedOut(
error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class AuthRequestingCode implements AuthState {
  const AuthRequestingCode({required this.email});
  

 final  String email;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthRequestingCodeCopyWith<AuthRequestingCode> get copyWith => _$AuthRequestingCodeCopyWithImpl<AuthRequestingCode>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthRequestingCode&&(identical(other.email, email) || other.email == email));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email);
}



}

/// @nodoc
abstract mixin class $AuthRequestingCodeCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory $AuthRequestingCodeCopyWith(AuthRequestingCode value, $Res Function(AuthRequestingCode) _then) = _$AuthRequestingCodeCopyWithImpl;
@useResult
$Res call({
 String email
});




}
/// @nodoc
class _$AuthRequestingCodeCopyWithImpl<$Res>
    implements $AuthRequestingCodeCopyWith<$Res> {
  _$AuthRequestingCodeCopyWithImpl(this._self, this._then);

  final AuthRequestingCode _self;
  final $Res Function(AuthRequestingCode) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,}) {
  return _then(AuthRequestingCode(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class AuthCodeSent implements AuthState {
  const AuthCodeSent({required this.email, this.error});
  

 final  String email;
 final  String? error;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthCodeSentCopyWith<AuthCodeSent> get copyWith => _$AuthCodeSentCopyWithImpl<AuthCodeSent>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthCodeSent&&(identical(other.email, email) || other.email == email)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email,error);
}



}

/// @nodoc
abstract mixin class $AuthCodeSentCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory $AuthCodeSentCopyWith(AuthCodeSent value, $Res Function(AuthCodeSent) _then) = _$AuthCodeSentCopyWithImpl;
@useResult
$Res call({
 String email, String? error
});




}
/// @nodoc
class _$AuthCodeSentCopyWithImpl<$Res>
    implements $AuthCodeSentCopyWith<$Res> {
  _$AuthCodeSentCopyWithImpl(this._self, this._then);

  final AuthCodeSent _self;
  final $Res Function(AuthCodeSent) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,Object? error = freezed,}) {
  return _then(AuthCodeSent(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class AuthVerifying implements AuthState {
  const AuthVerifying({required this.email});
  

 final  String email;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthVerifyingCopyWith<AuthVerifying> get copyWith => _$AuthVerifyingCopyWithImpl<AuthVerifying>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthVerifying&&(identical(other.email, email) || other.email == email));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email);
}



}

/// @nodoc
abstract mixin class $AuthVerifyingCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory $AuthVerifyingCopyWith(AuthVerifying value, $Res Function(AuthVerifying) _then) = _$AuthVerifyingCopyWithImpl;
@useResult
$Res call({
 String email
});




}
/// @nodoc
class _$AuthVerifyingCopyWithImpl<$Res>
    implements $AuthVerifyingCopyWith<$Res> {
  _$AuthVerifyingCopyWithImpl(this._self, this._then);

  final AuthVerifying _self;
  final $Res Function(AuthVerifying) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,}) {
  return _then(AuthVerifying(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class AuthSigningInWith implements AuthState {
  const AuthSigningInWith(this.provider);
  

 final  IdentityProvider provider;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthSigningInWithCopyWith<AuthSigningInWith> get copyWith => _$AuthSigningInWithCopyWithImpl<AuthSigningInWith>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthSigningInWith&&(identical(other.provider, provider) || other.provider == provider));
}


@override
int get hashCode {
    return Object.hash(runtimeType,provider);
}



}

/// @nodoc
abstract mixin class $AuthSigningInWithCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory $AuthSigningInWithCopyWith(AuthSigningInWith value, $Res Function(AuthSigningInWith) _then) = _$AuthSigningInWithCopyWithImpl;
@useResult
$Res call({
 IdentityProvider provider
});




}
/// @nodoc
class _$AuthSigningInWithCopyWithImpl<$Res>
    implements $AuthSigningInWithCopyWith<$Res> {
  _$AuthSigningInWithCopyWithImpl(this._self, this._then);

  final AuthSigningInWith _self;
  final $Res Function(AuthSigningInWith) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? provider = null,}) {
  return _then(AuthSigningInWith(
null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as IdentityProvider,
  ));
}


}

/// @nodoc


class AuthPasswordRequired implements AuthState {
  const AuthPasswordRequired({required this.email, this.error});
  

 final  String email;
 final  String? error;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthPasswordRequiredCopyWith<AuthPasswordRequired> get copyWith => _$AuthPasswordRequiredCopyWithImpl<AuthPasswordRequired>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthPasswordRequired&&(identical(other.email, email) || other.email == email)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email,error);
}



}

/// @nodoc
abstract mixin class $AuthPasswordRequiredCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory $AuthPasswordRequiredCopyWith(AuthPasswordRequired value, $Res Function(AuthPasswordRequired) _then) = _$AuthPasswordRequiredCopyWithImpl;
@useResult
$Res call({
 String email, String? error
});




}
/// @nodoc
class _$AuthPasswordRequiredCopyWithImpl<$Res>
    implements $AuthPasswordRequiredCopyWith<$Res> {
  _$AuthPasswordRequiredCopyWithImpl(this._self, this._then);

  final AuthPasswordRequired _self;
  final $Res Function(AuthPasswordRequired) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,Object? error = freezed,}) {
  return _then(AuthPasswordRequired(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class AuthCheckingPassword implements AuthState {
  const AuthCheckingPassword({required this.email});
  

 final  String email;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthCheckingPasswordCopyWith<AuthCheckingPassword> get copyWith => _$AuthCheckingPasswordCopyWithImpl<AuthCheckingPassword>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthCheckingPassword&&(identical(other.email, email) || other.email == email));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email);
}



}

/// @nodoc
abstract mixin class $AuthCheckingPasswordCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory $AuthCheckingPasswordCopyWith(AuthCheckingPassword value, $Res Function(AuthCheckingPassword) _then) = _$AuthCheckingPasswordCopyWithImpl;
@useResult
$Res call({
 String email
});




}
/// @nodoc
class _$AuthCheckingPasswordCopyWithImpl<$Res>
    implements $AuthCheckingPasswordCopyWith<$Res> {
  _$AuthCheckingPasswordCopyWithImpl(this._self, this._then);

  final AuthCheckingPassword _self;
  final $Res Function(AuthCheckingPassword) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,}) {
  return _then(AuthCheckingPassword(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class AuthSignedIn implements AuthState {
  const AuthSignedIn({required this.userId, required this.identity});
  

 final  String userId;
 final  SignInIdentity identity;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthSignedInCopyWith<AuthSignedIn> get copyWith => _$AuthSignedInCopyWithImpl<AuthSignedIn>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthSignedIn&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.identity, identity) || other.identity == identity));
}


@override
int get hashCode {
    return Object.hash(runtimeType,userId,identity);
}



}

/// @nodoc
abstract mixin class $AuthSignedInCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory $AuthSignedInCopyWith(AuthSignedIn value, $Res Function(AuthSignedIn) _then) = _$AuthSignedInCopyWithImpl;
@useResult
$Res call({
 String userId, SignInIdentity identity
});


$SignInIdentityCopyWith<$Res> get identity;

}
/// @nodoc
class _$AuthSignedInCopyWithImpl<$Res>
    implements $AuthSignedInCopyWith<$Res> {
  _$AuthSignedInCopyWithImpl(this._self, this._then);

  final AuthSignedIn _self;
  final $Res Function(AuthSignedIn) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? identity = null,}) {
  return _then(AuthSignedIn(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,identity: null == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as SignInIdentity,
  ));
}

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SignInIdentityCopyWith<$Res> get identity {
  
  return $SignInIdentityCopyWith<$Res>(_self.identity, (value) {
    return _then(_self.copyWith(identity: value));
  });
}
}

// dart format on
