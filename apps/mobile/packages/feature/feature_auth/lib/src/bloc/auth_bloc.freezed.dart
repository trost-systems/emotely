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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AuthSignInSubmitted value)?  signInSubmitted,TResult Function( AuthSignUpSubmitted value)?  signUpSubmitted,TResult Function( AuthResetRequested value)?  resetRequested,TResult Function( AuthConfirmationSubmitted value)?  confirmationSubmitted,TResult Function( AuthResetSubmitted value)?  resetSubmitted,TResult Function( AuthNewPasswordSubmitted value)?  newPasswordSubmitted,TResult Function( AuthCodeResendRequested value)?  codeResendRequested,TResult Function( AuthProviderSelected value)?  providerSelected,TResult Function( AuthLanguageShown value)?  languageShown,TResult Function( AuthEmailChangeRequested value)?  emailChangeRequested,TResult Function( AuthSignOutRequested value)?  signOutRequested,TResult Function( AuthSessionChanged value)?  sessionChanged,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AuthSignInSubmitted() when signInSubmitted != null:
return signInSubmitted(_that);case AuthSignUpSubmitted() when signUpSubmitted != null:
return signUpSubmitted(_that);case AuthResetRequested() when resetRequested != null:
return resetRequested(_that);case AuthConfirmationSubmitted() when confirmationSubmitted != null:
return confirmationSubmitted(_that);case AuthResetSubmitted() when resetSubmitted != null:
return resetSubmitted(_that);case AuthNewPasswordSubmitted() when newPasswordSubmitted != null:
return newPasswordSubmitted(_that);case AuthCodeResendRequested() when codeResendRequested != null:
return codeResendRequested(_that);case AuthProviderSelected() when providerSelected != null:
return providerSelected(_that);case AuthLanguageShown() when languageShown != null:
return languageShown(_that);case AuthEmailChangeRequested() when emailChangeRequested != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AuthSignInSubmitted value)  signInSubmitted,required TResult Function( AuthSignUpSubmitted value)  signUpSubmitted,required TResult Function( AuthResetRequested value)  resetRequested,required TResult Function( AuthConfirmationSubmitted value)  confirmationSubmitted,required TResult Function( AuthResetSubmitted value)  resetSubmitted,required TResult Function( AuthNewPasswordSubmitted value)  newPasswordSubmitted,required TResult Function( AuthCodeResendRequested value)  codeResendRequested,required TResult Function( AuthProviderSelected value)  providerSelected,required TResult Function( AuthLanguageShown value)  languageShown,required TResult Function( AuthEmailChangeRequested value)  emailChangeRequested,required TResult Function( AuthSignOutRequested value)  signOutRequested,required TResult Function( AuthSessionChanged value)  sessionChanged,}){
final _that = this;
switch (_that) {
case AuthSignInSubmitted():
return signInSubmitted(_that);case AuthSignUpSubmitted():
return signUpSubmitted(_that);case AuthResetRequested():
return resetRequested(_that);case AuthConfirmationSubmitted():
return confirmationSubmitted(_that);case AuthResetSubmitted():
return resetSubmitted(_that);case AuthNewPasswordSubmitted():
return newPasswordSubmitted(_that);case AuthCodeResendRequested():
return codeResendRequested(_that);case AuthProviderSelected():
return providerSelected(_that);case AuthLanguageShown():
return languageShown(_that);case AuthEmailChangeRequested():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AuthSignInSubmitted value)?  signInSubmitted,TResult? Function( AuthSignUpSubmitted value)?  signUpSubmitted,TResult? Function( AuthResetRequested value)?  resetRequested,TResult? Function( AuthConfirmationSubmitted value)?  confirmationSubmitted,TResult? Function( AuthResetSubmitted value)?  resetSubmitted,TResult? Function( AuthNewPasswordSubmitted value)?  newPasswordSubmitted,TResult? Function( AuthCodeResendRequested value)?  codeResendRequested,TResult? Function( AuthProviderSelected value)?  providerSelected,TResult? Function( AuthLanguageShown value)?  languageShown,TResult? Function( AuthEmailChangeRequested value)?  emailChangeRequested,TResult? Function( AuthSignOutRequested value)?  signOutRequested,TResult? Function( AuthSessionChanged value)?  sessionChanged,}){
final _that = this;
switch (_that) {
case AuthSignInSubmitted() when signInSubmitted != null:
return signInSubmitted(_that);case AuthSignUpSubmitted() when signUpSubmitted != null:
return signUpSubmitted(_that);case AuthResetRequested() when resetRequested != null:
return resetRequested(_that);case AuthConfirmationSubmitted() when confirmationSubmitted != null:
return confirmationSubmitted(_that);case AuthResetSubmitted() when resetSubmitted != null:
return resetSubmitted(_that);case AuthNewPasswordSubmitted() when newPasswordSubmitted != null:
return newPasswordSubmitted(_that);case AuthCodeResendRequested() when codeResendRequested != null:
return codeResendRequested(_that);case AuthProviderSelected() when providerSelected != null:
return providerSelected(_that);case AuthLanguageShown() when languageShown != null:
return languageShown(_that);case AuthEmailChangeRequested() when emailChangeRequested != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String email,  String password)?  signInSubmitted,TResult Function( String email,  String password)?  signUpSubmitted,TResult Function( String email)?  resetRequested,TResult Function( String code)?  confirmationSubmitted,TResult Function( String code,  String newPassword)?  resetSubmitted,TResult Function( String newPassword)?  newPasswordSubmitted,TResult Function()?  codeResendRequested,TResult Function( IdentityProvider provider)?  providerSelected,TResult Function( String languageCode)?  languageShown,TResult Function()?  emailChangeRequested,TResult Function()?  signOutRequested,TResult Function( String? userId,  SignInIdentity? identity)?  sessionChanged,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AuthSignInSubmitted() when signInSubmitted != null:
return signInSubmitted(_that.email,_that.password);case AuthSignUpSubmitted() when signUpSubmitted != null:
return signUpSubmitted(_that.email,_that.password);case AuthResetRequested() when resetRequested != null:
return resetRequested(_that.email);case AuthConfirmationSubmitted() when confirmationSubmitted != null:
return confirmationSubmitted(_that.code);case AuthResetSubmitted() when resetSubmitted != null:
return resetSubmitted(_that.code,_that.newPassword);case AuthNewPasswordSubmitted() when newPasswordSubmitted != null:
return newPasswordSubmitted(_that.newPassword);case AuthCodeResendRequested() when codeResendRequested != null:
return codeResendRequested();case AuthProviderSelected() when providerSelected != null:
return providerSelected(_that.provider);case AuthLanguageShown() when languageShown != null:
return languageShown(_that.languageCode);case AuthEmailChangeRequested() when emailChangeRequested != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String email,  String password)  signInSubmitted,required TResult Function( String email,  String password)  signUpSubmitted,required TResult Function( String email)  resetRequested,required TResult Function( String code)  confirmationSubmitted,required TResult Function( String code,  String newPassword)  resetSubmitted,required TResult Function( String newPassword)  newPasswordSubmitted,required TResult Function()  codeResendRequested,required TResult Function( IdentityProvider provider)  providerSelected,required TResult Function( String languageCode)  languageShown,required TResult Function()  emailChangeRequested,required TResult Function()  signOutRequested,required TResult Function( String? userId,  SignInIdentity? identity)  sessionChanged,}) {final _that = this;
switch (_that) {
case AuthSignInSubmitted():
return signInSubmitted(_that.email,_that.password);case AuthSignUpSubmitted():
return signUpSubmitted(_that.email,_that.password);case AuthResetRequested():
return resetRequested(_that.email);case AuthConfirmationSubmitted():
return confirmationSubmitted(_that.code);case AuthResetSubmitted():
return resetSubmitted(_that.code,_that.newPassword);case AuthNewPasswordSubmitted():
return newPasswordSubmitted(_that.newPassword);case AuthCodeResendRequested():
return codeResendRequested();case AuthProviderSelected():
return providerSelected(_that.provider);case AuthLanguageShown():
return languageShown(_that.languageCode);case AuthEmailChangeRequested():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String email,  String password)?  signInSubmitted,TResult? Function( String email,  String password)?  signUpSubmitted,TResult? Function( String email)?  resetRequested,TResult? Function( String code)?  confirmationSubmitted,TResult? Function( String code,  String newPassword)?  resetSubmitted,TResult? Function( String newPassword)?  newPasswordSubmitted,TResult? Function()?  codeResendRequested,TResult? Function( IdentityProvider provider)?  providerSelected,TResult? Function( String languageCode)?  languageShown,TResult? Function()?  emailChangeRequested,TResult? Function()?  signOutRequested,TResult? Function( String? userId,  SignInIdentity? identity)?  sessionChanged,}) {final _that = this;
switch (_that) {
case AuthSignInSubmitted() when signInSubmitted != null:
return signInSubmitted(_that.email,_that.password);case AuthSignUpSubmitted() when signUpSubmitted != null:
return signUpSubmitted(_that.email,_that.password);case AuthResetRequested() when resetRequested != null:
return resetRequested(_that.email);case AuthConfirmationSubmitted() when confirmationSubmitted != null:
return confirmationSubmitted(_that.code);case AuthResetSubmitted() when resetSubmitted != null:
return resetSubmitted(_that.code,_that.newPassword);case AuthNewPasswordSubmitted() when newPasswordSubmitted != null:
return newPasswordSubmitted(_that.newPassword);case AuthCodeResendRequested() when codeResendRequested != null:
return codeResendRequested();case AuthProviderSelected() when providerSelected != null:
return providerSelected(_that.provider);case AuthLanguageShown() when languageShown != null:
return languageShown(_that.languageCode);case AuthEmailChangeRequested() when emailChangeRequested != null:
return emailChangeRequested();case AuthSignOutRequested() when signOutRequested != null:
return signOutRequested();case AuthSessionChanged() when sessionChanged != null:
return sessionChanged(_that.userId,_that.identity);case _:
  return null;

}
}

}

/// @nodoc


class AuthSignInSubmitted implements AuthEvent {
  const AuthSignInSubmitted(this.email, this.password);
  

 final  String email;
 final  String password;

/// Create a copy of AuthEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthSignInSubmittedCopyWith<AuthSignInSubmitted> get copyWith => _$AuthSignInSubmittedCopyWithImpl<AuthSignInSubmitted>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthSignInSubmitted&&(identical(other.email, email) || other.email == email)&&(identical(other.password, password) || other.password == password));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email,password);
}



}

/// @nodoc
abstract mixin class $AuthSignInSubmittedCopyWith<$Res> implements $AuthEventCopyWith<$Res> {
  factory $AuthSignInSubmittedCopyWith(AuthSignInSubmitted value, $Res Function(AuthSignInSubmitted) _then) = _$AuthSignInSubmittedCopyWithImpl;
@useResult
$Res call({
 String email, String password
});




}
/// @nodoc
class _$AuthSignInSubmittedCopyWithImpl<$Res>
    implements $AuthSignInSubmittedCopyWith<$Res> {
  _$AuthSignInSubmittedCopyWithImpl(this._self, this._then);

  final AuthSignInSubmitted _self;
  final $Res Function(AuthSignInSubmitted) _then;

/// Create a copy of AuthEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,Object? password = null,}) {
  return _then(AuthSignInSubmitted(
null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class AuthSignUpSubmitted implements AuthEvent {
  const AuthSignUpSubmitted(this.email, this.password);
  

 final  String email;
 final  String password;

/// Create a copy of AuthEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthSignUpSubmittedCopyWith<AuthSignUpSubmitted> get copyWith => _$AuthSignUpSubmittedCopyWithImpl<AuthSignUpSubmitted>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthSignUpSubmitted&&(identical(other.email, email) || other.email == email)&&(identical(other.password, password) || other.password == password));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email,password);
}



}

/// @nodoc
abstract mixin class $AuthSignUpSubmittedCopyWith<$Res> implements $AuthEventCopyWith<$Res> {
  factory $AuthSignUpSubmittedCopyWith(AuthSignUpSubmitted value, $Res Function(AuthSignUpSubmitted) _then) = _$AuthSignUpSubmittedCopyWithImpl;
@useResult
$Res call({
 String email, String password
});




}
/// @nodoc
class _$AuthSignUpSubmittedCopyWithImpl<$Res>
    implements $AuthSignUpSubmittedCopyWith<$Res> {
  _$AuthSignUpSubmittedCopyWithImpl(this._self, this._then);

  final AuthSignUpSubmitted _self;
  final $Res Function(AuthSignUpSubmitted) _then;

/// Create a copy of AuthEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,Object? password = null,}) {
  return _then(AuthSignUpSubmitted(
null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class AuthResetRequested implements AuthEvent {
  const AuthResetRequested(this.email);
  

 final  String email;

/// Create a copy of AuthEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthResetRequestedCopyWith<AuthResetRequested> get copyWith => _$AuthResetRequestedCopyWithImpl<AuthResetRequested>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthResetRequested&&(identical(other.email, email) || other.email == email));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email);
}



}

/// @nodoc
abstract mixin class $AuthResetRequestedCopyWith<$Res> implements $AuthEventCopyWith<$Res> {
  factory $AuthResetRequestedCopyWith(AuthResetRequested value, $Res Function(AuthResetRequested) _then) = _$AuthResetRequestedCopyWithImpl;
@useResult
$Res call({
 String email
});




}
/// @nodoc
class _$AuthResetRequestedCopyWithImpl<$Res>
    implements $AuthResetRequestedCopyWith<$Res> {
  _$AuthResetRequestedCopyWithImpl(this._self, this._then);

  final AuthResetRequested _self;
  final $Res Function(AuthResetRequested) _then;

/// Create a copy of AuthEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,}) {
  return _then(AuthResetRequested(
null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class AuthConfirmationSubmitted implements AuthEvent {
  const AuthConfirmationSubmitted(this.code);
  

 final  String code;

/// Create a copy of AuthEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthConfirmationSubmittedCopyWith<AuthConfirmationSubmitted> get copyWith => _$AuthConfirmationSubmittedCopyWithImpl<AuthConfirmationSubmitted>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthConfirmationSubmitted&&(identical(other.code, code) || other.code == code));
}


@override
int get hashCode {
    return Object.hash(runtimeType,code);
}



}

/// @nodoc
abstract mixin class $AuthConfirmationSubmittedCopyWith<$Res> implements $AuthEventCopyWith<$Res> {
  factory $AuthConfirmationSubmittedCopyWith(AuthConfirmationSubmitted value, $Res Function(AuthConfirmationSubmitted) _then) = _$AuthConfirmationSubmittedCopyWithImpl;
@useResult
$Res call({
 String code
});




}
/// @nodoc
class _$AuthConfirmationSubmittedCopyWithImpl<$Res>
    implements $AuthConfirmationSubmittedCopyWith<$Res> {
  _$AuthConfirmationSubmittedCopyWithImpl(this._self, this._then);

  final AuthConfirmationSubmitted _self;
  final $Res Function(AuthConfirmationSubmitted) _then;

/// Create a copy of AuthEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? code = null,}) {
  return _then(AuthConfirmationSubmitted(
null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class AuthResetSubmitted implements AuthEvent {
  const AuthResetSubmitted(this.code, this.newPassword);
  

 final  String code;
 final  String newPassword;

/// Create a copy of AuthEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthResetSubmittedCopyWith<AuthResetSubmitted> get copyWith => _$AuthResetSubmittedCopyWithImpl<AuthResetSubmitted>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthResetSubmitted&&(identical(other.code, code) || other.code == code)&&(identical(other.newPassword, newPassword) || other.newPassword == newPassword));
}


@override
int get hashCode {
    return Object.hash(runtimeType,code,newPassword);
}



}

/// @nodoc
abstract mixin class $AuthResetSubmittedCopyWith<$Res> implements $AuthEventCopyWith<$Res> {
  factory $AuthResetSubmittedCopyWith(AuthResetSubmitted value, $Res Function(AuthResetSubmitted) _then) = _$AuthResetSubmittedCopyWithImpl;
@useResult
$Res call({
 String code, String newPassword
});




}
/// @nodoc
class _$AuthResetSubmittedCopyWithImpl<$Res>
    implements $AuthResetSubmittedCopyWith<$Res> {
  _$AuthResetSubmittedCopyWithImpl(this._self, this._then);

  final AuthResetSubmitted _self;
  final $Res Function(AuthResetSubmitted) _then;

/// Create a copy of AuthEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? code = null,Object? newPassword = null,}) {
  return _then(AuthResetSubmitted(
null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,null == newPassword ? _self.newPassword : newPassword // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class AuthNewPasswordSubmitted implements AuthEvent {
  const AuthNewPasswordSubmitted(this.newPassword);
  

 final  String newPassword;

/// Create a copy of AuthEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthNewPasswordSubmittedCopyWith<AuthNewPasswordSubmitted> get copyWith => _$AuthNewPasswordSubmittedCopyWithImpl<AuthNewPasswordSubmitted>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthNewPasswordSubmitted&&(identical(other.newPassword, newPassword) || other.newPassword == newPassword));
}


@override
int get hashCode {
    return Object.hash(runtimeType,newPassword);
}



}

/// @nodoc
abstract mixin class $AuthNewPasswordSubmittedCopyWith<$Res> implements $AuthEventCopyWith<$Res> {
  factory $AuthNewPasswordSubmittedCopyWith(AuthNewPasswordSubmitted value, $Res Function(AuthNewPasswordSubmitted) _then) = _$AuthNewPasswordSubmittedCopyWithImpl;
@useResult
$Res call({
 String newPassword
});




}
/// @nodoc
class _$AuthNewPasswordSubmittedCopyWithImpl<$Res>
    implements $AuthNewPasswordSubmittedCopyWith<$Res> {
  _$AuthNewPasswordSubmittedCopyWithImpl(this._self, this._then);

  final AuthNewPasswordSubmitted _self;
  final $Res Function(AuthNewPasswordSubmitted) _then;

/// Create a copy of AuthEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? newPassword = null,}) {
  return _then(AuthNewPasswordSubmitted(
null == newPassword ? _self.newPassword : newPassword // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class AuthCodeResendRequested implements AuthEvent {
  const AuthCodeResendRequested();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthCodeResendRequested);
}


@override
int get hashCode => runtimeType.hashCode;



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


class AuthLanguageShown implements AuthEvent {
  const AuthLanguageShown(this.languageCode);
  

 final  String languageCode;

/// Create a copy of AuthEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthLanguageShownCopyWith<AuthLanguageShown> get copyWith => _$AuthLanguageShownCopyWithImpl<AuthLanguageShown>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthLanguageShown&&(identical(other.languageCode, languageCode) || other.languageCode == languageCode));
}


@override
int get hashCode {
    return Object.hash(runtimeType,languageCode);
}



}

/// @nodoc
abstract mixin class $AuthLanguageShownCopyWith<$Res> implements $AuthEventCopyWith<$Res> {
  factory $AuthLanguageShownCopyWith(AuthLanguageShown value, $Res Function(AuthLanguageShown) _then) = _$AuthLanguageShownCopyWithImpl;
@useResult
$Res call({
 String languageCode
});




}
/// @nodoc
class _$AuthLanguageShownCopyWithImpl<$Res>
    implements $AuthLanguageShownCopyWith<$Res> {
  _$AuthLanguageShownCopyWithImpl(this._self, this._then);

  final AuthLanguageShown _self;
  final $Res Function(AuthLanguageShown) _then;

/// Create a copy of AuthEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? languageCode = null,}) {
  return _then(AuthLanguageShown(
null == languageCode ? _self.languageCode : languageCode // ignore: cast_nullable_to_non_nullable
as String,
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AuthSignedOut value)?  signedOut,TResult Function( AuthChecking value)?  checking,TResult Function( AuthSigningInWith value)?  signingInWith,TResult Function( AuthCodeSent value)?  codeSent,TResult Function( AuthCheckingCode value)?  checkingCode,TResult Function( AuthNewPasswordRequired value)?  newPasswordRequired,TResult Function( AuthSavingPassword value)?  savingPassword,TResult Function( AuthSignedIn value)?  signedIn,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AuthSignedOut() when signedOut != null:
return signedOut(_that);case AuthChecking() when checking != null:
return checking(_that);case AuthSigningInWith() when signingInWith != null:
return signingInWith(_that);case AuthCodeSent() when codeSent != null:
return codeSent(_that);case AuthCheckingCode() when checkingCode != null:
return checkingCode(_that);case AuthNewPasswordRequired() when newPasswordRequired != null:
return newPasswordRequired(_that);case AuthSavingPassword() when savingPassword != null:
return savingPassword(_that);case AuthSignedIn() when signedIn != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AuthSignedOut value)  signedOut,required TResult Function( AuthChecking value)  checking,required TResult Function( AuthSigningInWith value)  signingInWith,required TResult Function( AuthCodeSent value)  codeSent,required TResult Function( AuthCheckingCode value)  checkingCode,required TResult Function( AuthNewPasswordRequired value)  newPasswordRequired,required TResult Function( AuthSavingPassword value)  savingPassword,required TResult Function( AuthSignedIn value)  signedIn,}){
final _that = this;
switch (_that) {
case AuthSignedOut():
return signedOut(_that);case AuthChecking():
return checking(_that);case AuthSigningInWith():
return signingInWith(_that);case AuthCodeSent():
return codeSent(_that);case AuthCheckingCode():
return checkingCode(_that);case AuthNewPasswordRequired():
return newPasswordRequired(_that);case AuthSavingPassword():
return savingPassword(_that);case AuthSignedIn():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AuthSignedOut value)?  signedOut,TResult? Function( AuthChecking value)?  checking,TResult? Function( AuthSigningInWith value)?  signingInWith,TResult? Function( AuthCodeSent value)?  codeSent,TResult? Function( AuthCheckingCode value)?  checkingCode,TResult? Function( AuthNewPasswordRequired value)?  newPasswordRequired,TResult? Function( AuthSavingPassword value)?  savingPassword,TResult? Function( AuthSignedIn value)?  signedIn,}){
final _that = this;
switch (_that) {
case AuthSignedOut() when signedOut != null:
return signedOut(_that);case AuthChecking() when checking != null:
return checking(_that);case AuthSigningInWith() when signingInWith != null:
return signingInWith(_that);case AuthCodeSent() when codeSent != null:
return codeSent(_that);case AuthCheckingCode() when checkingCode != null:
return checkingCode(_that);case AuthNewPasswordRequired() when newPasswordRequired != null:
return newPasswordRequired(_that);case AuthSavingPassword() when savingPassword != null:
return savingPassword(_that);case AuthSignedIn() when signedIn != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( SignInProblem? problem,  String? email)?  signedOut,TResult Function( String email)?  checking,TResult Function( IdentityProvider provider)?  signingInWith,TResult Function( String email,  CodePurpose purpose,  SignInProblem? problem,  bool resent)?  codeSent,TResult Function( String email,  CodePurpose purpose)?  checkingCode,TResult Function( String email,  User user,  SignInProblem? problem)?  newPasswordRequired,TResult Function( String email,  User user)?  savingPassword,TResult Function( String userId,  SignInIdentity identity)?  signedIn,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AuthSignedOut() when signedOut != null:
return signedOut(_that.problem,_that.email);case AuthChecking() when checking != null:
return checking(_that.email);case AuthSigningInWith() when signingInWith != null:
return signingInWith(_that.provider);case AuthCodeSent() when codeSent != null:
return codeSent(_that.email,_that.purpose,_that.problem,_that.resent);case AuthCheckingCode() when checkingCode != null:
return checkingCode(_that.email,_that.purpose);case AuthNewPasswordRequired() when newPasswordRequired != null:
return newPasswordRequired(_that.email,_that.user,_that.problem);case AuthSavingPassword() when savingPassword != null:
return savingPassword(_that.email,_that.user);case AuthSignedIn() when signedIn != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( SignInProblem? problem,  String? email)  signedOut,required TResult Function( String email)  checking,required TResult Function( IdentityProvider provider)  signingInWith,required TResult Function( String email,  CodePurpose purpose,  SignInProblem? problem,  bool resent)  codeSent,required TResult Function( String email,  CodePurpose purpose)  checkingCode,required TResult Function( String email,  User user,  SignInProblem? problem)  newPasswordRequired,required TResult Function( String email,  User user)  savingPassword,required TResult Function( String userId,  SignInIdentity identity)  signedIn,}) {final _that = this;
switch (_that) {
case AuthSignedOut():
return signedOut(_that.problem,_that.email);case AuthChecking():
return checking(_that.email);case AuthSigningInWith():
return signingInWith(_that.provider);case AuthCodeSent():
return codeSent(_that.email,_that.purpose,_that.problem,_that.resent);case AuthCheckingCode():
return checkingCode(_that.email,_that.purpose);case AuthNewPasswordRequired():
return newPasswordRequired(_that.email,_that.user,_that.problem);case AuthSavingPassword():
return savingPassword(_that.email,_that.user);case AuthSignedIn():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( SignInProblem? problem,  String? email)?  signedOut,TResult? Function( String email)?  checking,TResult? Function( IdentityProvider provider)?  signingInWith,TResult? Function( String email,  CodePurpose purpose,  SignInProblem? problem,  bool resent)?  codeSent,TResult? Function( String email,  CodePurpose purpose)?  checkingCode,TResult? Function( String email,  User user,  SignInProblem? problem)?  newPasswordRequired,TResult? Function( String email,  User user)?  savingPassword,TResult? Function( String userId,  SignInIdentity identity)?  signedIn,}) {final _that = this;
switch (_that) {
case AuthSignedOut() when signedOut != null:
return signedOut(_that.problem,_that.email);case AuthChecking() when checking != null:
return checking(_that.email);case AuthSigningInWith() when signingInWith != null:
return signingInWith(_that.provider);case AuthCodeSent() when codeSent != null:
return codeSent(_that.email,_that.purpose,_that.problem,_that.resent);case AuthCheckingCode() when checkingCode != null:
return checkingCode(_that.email,_that.purpose);case AuthNewPasswordRequired() when newPasswordRequired != null:
return newPasswordRequired(_that.email,_that.user,_that.problem);case AuthSavingPassword() when savingPassword != null:
return savingPassword(_that.email,_that.user);case AuthSignedIn() when signedIn != null:
return signedIn(_that.userId,_that.identity);case _:
  return null;

}
}

}

/// @nodoc


class AuthSignedOut implements AuthState {
  const AuthSignedOut({this.problem, this.email});
  

 final  SignInProblem? problem;
 final  String? email;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthSignedOutCopyWith<AuthSignedOut> get copyWith => _$AuthSignedOutCopyWithImpl<AuthSignedOut>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthSignedOut&&(identical(other.problem, problem) || other.problem == problem)&&(identical(other.email, email) || other.email == email));
}


@override
int get hashCode {
    return Object.hash(runtimeType,problem,email);
}



}

/// @nodoc
abstract mixin class $AuthSignedOutCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory $AuthSignedOutCopyWith(AuthSignedOut value, $Res Function(AuthSignedOut) _then) = _$AuthSignedOutCopyWithImpl;
@useResult
$Res call({
 SignInProblem? problem, String? email
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
@pragma('vm:prefer-inline') $Res call({Object? problem = freezed,Object? email = freezed,}) {
  return _then(AuthSignedOut(
problem: freezed == problem ? _self.problem : problem // ignore: cast_nullable_to_non_nullable
as SignInProblem?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class AuthChecking implements AuthState {
  const AuthChecking({required this.email});
  

 final  String email;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthCheckingCopyWith<AuthChecking> get copyWith => _$AuthCheckingCopyWithImpl<AuthChecking>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthChecking&&(identical(other.email, email) || other.email == email));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email);
}



}

/// @nodoc
abstract mixin class $AuthCheckingCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory $AuthCheckingCopyWith(AuthChecking value, $Res Function(AuthChecking) _then) = _$AuthCheckingCopyWithImpl;
@useResult
$Res call({
 String email
});




}
/// @nodoc
class _$AuthCheckingCopyWithImpl<$Res>
    implements $AuthCheckingCopyWith<$Res> {
  _$AuthCheckingCopyWithImpl(this._self, this._then);

  final AuthChecking _self;
  final $Res Function(AuthChecking) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,}) {
  return _then(AuthChecking(
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


class AuthCodeSent implements AuthState {
  const AuthCodeSent({required this.email, required this.purpose, this.problem, this.resent = false});
  

 final  String email;
 final  CodePurpose purpose;
 final  SignInProblem? problem;
@JsonKey() final  bool resent;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthCodeSentCopyWith<AuthCodeSent> get copyWith => _$AuthCodeSentCopyWithImpl<AuthCodeSent>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthCodeSent&&(identical(other.email, email) || other.email == email)&&(identical(other.purpose, purpose) || other.purpose == purpose)&&(identical(other.problem, problem) || other.problem == problem)&&(identical(other.resent, resent) || other.resent == resent));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email,purpose,problem,resent);
}



}

/// @nodoc
abstract mixin class $AuthCodeSentCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory $AuthCodeSentCopyWith(AuthCodeSent value, $Res Function(AuthCodeSent) _then) = _$AuthCodeSentCopyWithImpl;
@useResult
$Res call({
 String email, CodePurpose purpose, SignInProblem? problem, bool resent
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
@pragma('vm:prefer-inline') $Res call({Object? email = null,Object? purpose = null,Object? problem = freezed,Object? resent = null,}) {
  return _then(AuthCodeSent(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,purpose: null == purpose ? _self.purpose : purpose // ignore: cast_nullable_to_non_nullable
as CodePurpose,problem: freezed == problem ? _self.problem : problem // ignore: cast_nullable_to_non_nullable
as SignInProblem?,resent: null == resent ? _self.resent : resent // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class AuthCheckingCode implements AuthState {
  const AuthCheckingCode({required this.email, required this.purpose});
  

 final  String email;
 final  CodePurpose purpose;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthCheckingCodeCopyWith<AuthCheckingCode> get copyWith => _$AuthCheckingCodeCopyWithImpl<AuthCheckingCode>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthCheckingCode&&(identical(other.email, email) || other.email == email)&&(identical(other.purpose, purpose) || other.purpose == purpose));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email,purpose);
}



}

/// @nodoc
abstract mixin class $AuthCheckingCodeCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory $AuthCheckingCodeCopyWith(AuthCheckingCode value, $Res Function(AuthCheckingCode) _then) = _$AuthCheckingCodeCopyWithImpl;
@useResult
$Res call({
 String email, CodePurpose purpose
});




}
/// @nodoc
class _$AuthCheckingCodeCopyWithImpl<$Res>
    implements $AuthCheckingCodeCopyWith<$Res> {
  _$AuthCheckingCodeCopyWithImpl(this._self, this._then);

  final AuthCheckingCode _self;
  final $Res Function(AuthCheckingCode) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,Object? purpose = null,}) {
  return _then(AuthCheckingCode(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,purpose: null == purpose ? _self.purpose : purpose // ignore: cast_nullable_to_non_nullable
as CodePurpose,
  ));
}


}

/// @nodoc


class AuthNewPasswordRequired implements AuthState {
  const AuthNewPasswordRequired({required this.email, required this.user, this.problem});
  

 final  String email;
 final  User user;
 final  SignInProblem? problem;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthNewPasswordRequiredCopyWith<AuthNewPasswordRequired> get copyWith => _$AuthNewPasswordRequiredCopyWithImpl<AuthNewPasswordRequired>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthNewPasswordRequired&&(identical(other.email, email) || other.email == email)&&(identical(other.user, user) || other.user == user)&&(identical(other.problem, problem) || other.problem == problem));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email,user,problem);
}



}

/// @nodoc
abstract mixin class $AuthNewPasswordRequiredCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory $AuthNewPasswordRequiredCopyWith(AuthNewPasswordRequired value, $Res Function(AuthNewPasswordRequired) _then) = _$AuthNewPasswordRequiredCopyWithImpl;
@useResult
$Res call({
 String email, User user, SignInProblem? problem
});




}
/// @nodoc
class _$AuthNewPasswordRequiredCopyWithImpl<$Res>
    implements $AuthNewPasswordRequiredCopyWith<$Res> {
  _$AuthNewPasswordRequiredCopyWithImpl(this._self, this._then);

  final AuthNewPasswordRequired _self;
  final $Res Function(AuthNewPasswordRequired) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,Object? user = null,Object? problem = freezed,}) {
  return _then(AuthNewPasswordRequired(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as User,problem: freezed == problem ? _self.problem : problem // ignore: cast_nullable_to_non_nullable
as SignInProblem?,
  ));
}


}

/// @nodoc


class AuthSavingPassword implements AuthState {
  const AuthSavingPassword({required this.email, required this.user});
  

 final  String email;
 final  User user;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthSavingPasswordCopyWith<AuthSavingPassword> get copyWith => _$AuthSavingPasswordCopyWithImpl<AuthSavingPassword>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthSavingPassword&&(identical(other.email, email) || other.email == email)&&(identical(other.user, user) || other.user == user));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email,user);
}



}

/// @nodoc
abstract mixin class $AuthSavingPasswordCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory $AuthSavingPasswordCopyWith(AuthSavingPassword value, $Res Function(AuthSavingPassword) _then) = _$AuthSavingPasswordCopyWithImpl;
@useResult
$Res call({
 String email, User user
});




}
/// @nodoc
class _$AuthSavingPasswordCopyWithImpl<$Res>
    implements $AuthSavingPasswordCopyWith<$Res> {
  _$AuthSavingPasswordCopyWithImpl(this._self, this._then);

  final AuthSavingPassword _self;
  final $Res Function(AuthSavingPassword) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,Object? user = null,}) {
  return _then(AuthSavingPassword(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as User,
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
