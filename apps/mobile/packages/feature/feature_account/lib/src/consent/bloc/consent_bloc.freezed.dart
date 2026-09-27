// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'consent_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ConsentEvent {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConsentEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ConsentEvent()';
}


}

/// @nodoc
class $ConsentEventCopyWith<$Res>  {
$ConsentEventCopyWith(ConsentEvent _, $Res Function(ConsentEvent) __);
}


/// Adds pattern-matching-related methods to [ConsentEvent].
extension ConsentEventPatterns on ConsentEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ConsentLoaded value)?  loaded,TResult Function( ConsentGranted value)?  granted,TResult Function( ConsentWithdrawn value)?  withdrawn,TResult Function( ConsentDeclined value)?  declined,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ConsentLoaded() when loaded != null:
return loaded(_that);case ConsentGranted() when granted != null:
return granted(_that);case ConsentWithdrawn() when withdrawn != null:
return withdrawn(_that);case ConsentDeclined() when declined != null:
return declined(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ConsentLoaded value)  loaded,required TResult Function( ConsentGranted value)  granted,required TResult Function( ConsentWithdrawn value)  withdrawn,required TResult Function( ConsentDeclined value)  declined,}){
final _that = this;
switch (_that) {
case ConsentLoaded():
return loaded(_that);case ConsentGranted():
return granted(_that);case ConsentWithdrawn():
return withdrawn(_that);case ConsentDeclined():
return declined(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ConsentLoaded value)?  loaded,TResult? Function( ConsentGranted value)?  granted,TResult? Function( ConsentWithdrawn value)?  withdrawn,TResult? Function( ConsentDeclined value)?  declined,}){
final _that = this;
switch (_that) {
case ConsentLoaded() when loaded != null:
return loaded(_that);case ConsentGranted() when granted != null:
return granted(_that);case ConsentWithdrawn() when withdrawn != null:
return withdrawn(_that);case ConsentDeclined() when declined != null:
return declined(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( bool withDate)?  loaded,TResult Function()?  granted,TResult Function()?  withdrawn,TResult Function()?  declined,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ConsentLoaded() when loaded != null:
return loaded(_that.withDate);case ConsentGranted() when granted != null:
return granted();case ConsentWithdrawn() when withdrawn != null:
return withdrawn();case ConsentDeclined() when declined != null:
return declined();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( bool withDate)  loaded,required TResult Function()  granted,required TResult Function()  withdrawn,required TResult Function()  declined,}) {final _that = this;
switch (_that) {
case ConsentLoaded():
return loaded(_that.withDate);case ConsentGranted():
return granted();case ConsentWithdrawn():
return withdrawn();case ConsentDeclined():
return declined();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( bool withDate)?  loaded,TResult? Function()?  granted,TResult? Function()?  withdrawn,TResult? Function()?  declined,}) {final _that = this;
switch (_that) {
case ConsentLoaded() when loaded != null:
return loaded(_that.withDate);case ConsentGranted() when granted != null:
return granted();case ConsentWithdrawn() when withdrawn != null:
return withdrawn();case ConsentDeclined() when declined != null:
return declined();case _:
  return null;

}
}

}

/// @nodoc


class ConsentLoaded implements ConsentEvent {
  const ConsentLoaded({this.withDate = false});
  

@JsonKey() final  bool withDate;

/// Create a copy of ConsentEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConsentLoadedCopyWith<ConsentLoaded> get copyWith => _$ConsentLoadedCopyWithImpl<ConsentLoaded>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConsentLoaded&&(identical(other.withDate, withDate) || other.withDate == withDate));
}


@override
int get hashCode {
    return Object.hash(runtimeType,withDate);
}

@override
String toString() {
    return 'ConsentEvent.loaded(withDate: $withDate)';
}


}

/// @nodoc
abstract mixin class $ConsentLoadedCopyWith<$Res> implements $ConsentEventCopyWith<$Res> {
  factory $ConsentLoadedCopyWith(ConsentLoaded value, $Res Function(ConsentLoaded) _then) = _$ConsentLoadedCopyWithImpl;
@useResult
$Res call({
 bool withDate
});




}
/// @nodoc
class _$ConsentLoadedCopyWithImpl<$Res>
    implements $ConsentLoadedCopyWith<$Res> {
  _$ConsentLoadedCopyWithImpl(this._self, this._then);

  final ConsentLoaded _self;
  final $Res Function(ConsentLoaded) _then;

/// Create a copy of ConsentEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? withDate = null,}) {
  return _then(ConsentLoaded(
withDate: null == withDate ? _self.withDate : withDate // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class ConsentGranted implements ConsentEvent {
  const ConsentGranted();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConsentGranted);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ConsentEvent.granted()';
}


}




/// @nodoc


class ConsentWithdrawn implements ConsentEvent {
  const ConsentWithdrawn();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConsentWithdrawn);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ConsentEvent.withdrawn()';
}


}




/// @nodoc


class ConsentDeclined implements ConsentEvent {
  const ConsentDeclined();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConsentDeclined);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ConsentEvent.declined()';
}


}




/// @nodoc
mixin _$ConsentState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConsentState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ConsentState()';
}


}

/// @nodoc
class $ConsentStateCopyWith<$Res>  {
$ConsentStateCopyWith(ConsentState _, $Res Function(ConsentState) __);
}


/// Adds pattern-matching-related methods to [ConsentState].
extension ConsentStatePatterns on ConsentState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ConsentUnknown value)?  unknown,TResult Function( ConsentKnown value)?  known,TResult Function( ConsentBusy value)?  busy,TResult Function( ConsentFailure value)?  failure,TResult Function( ConsentWriteFailure value)?  writeFailure,TResult Function( ConsentWithdrawFailure value)?  withdrawFailure,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ConsentUnknown() when unknown != null:
return unknown(_that);case ConsentKnown() when known != null:
return known(_that);case ConsentBusy() when busy != null:
return busy(_that);case ConsentFailure() when failure != null:
return failure(_that);case ConsentWriteFailure() when writeFailure != null:
return writeFailure(_that);case ConsentWithdrawFailure() when withdrawFailure != null:
return withdrawFailure(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ConsentUnknown value)  unknown,required TResult Function( ConsentKnown value)  known,required TResult Function( ConsentBusy value)  busy,required TResult Function( ConsentFailure value)  failure,required TResult Function( ConsentWriteFailure value)  writeFailure,required TResult Function( ConsentWithdrawFailure value)  withdrawFailure,}){
final _that = this;
switch (_that) {
case ConsentUnknown():
return unknown(_that);case ConsentKnown():
return known(_that);case ConsentBusy():
return busy(_that);case ConsentFailure():
return failure(_that);case ConsentWriteFailure():
return writeFailure(_that);case ConsentWithdrawFailure():
return withdrawFailure(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ConsentUnknown value)?  unknown,TResult? Function( ConsentKnown value)?  known,TResult? Function( ConsentBusy value)?  busy,TResult? Function( ConsentFailure value)?  failure,TResult? Function( ConsentWriteFailure value)?  writeFailure,TResult? Function( ConsentWithdrawFailure value)?  withdrawFailure,}){
final _that = this;
switch (_that) {
case ConsentUnknown() when unknown != null:
return unknown(_that);case ConsentKnown() when known != null:
return known(_that);case ConsentBusy() when busy != null:
return busy(_that);case ConsentFailure() when failure != null:
return failure(_that);case ConsentWriteFailure() when writeFailure != null:
return writeFailure(_that);case ConsentWithdrawFailure() when withdrawFailure != null:
return withdrawFailure(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  unknown,TResult Function( bool granted,  bool justDeclined,  DateTime? since)?  known,TResult Function()?  busy,TResult Function()?  failure,TResult Function()?  writeFailure,TResult Function()?  withdrawFailure,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ConsentUnknown() when unknown != null:
return unknown();case ConsentKnown() when known != null:
return known(_that.granted,_that.justDeclined,_that.since);case ConsentBusy() when busy != null:
return busy();case ConsentFailure() when failure != null:
return failure();case ConsentWriteFailure() when writeFailure != null:
return writeFailure();case ConsentWithdrawFailure() when withdrawFailure != null:
return withdrawFailure();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  unknown,required TResult Function( bool granted,  bool justDeclined,  DateTime? since)  known,required TResult Function()  busy,required TResult Function()  failure,required TResult Function()  writeFailure,required TResult Function()  withdrawFailure,}) {final _that = this;
switch (_that) {
case ConsentUnknown():
return unknown();case ConsentKnown():
return known(_that.granted,_that.justDeclined,_that.since);case ConsentBusy():
return busy();case ConsentFailure():
return failure();case ConsentWriteFailure():
return writeFailure();case ConsentWithdrawFailure():
return withdrawFailure();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  unknown,TResult? Function( bool granted,  bool justDeclined,  DateTime? since)?  known,TResult? Function()?  busy,TResult? Function()?  failure,TResult? Function()?  writeFailure,TResult? Function()?  withdrawFailure,}) {final _that = this;
switch (_that) {
case ConsentUnknown() when unknown != null:
return unknown();case ConsentKnown() when known != null:
return known(_that.granted,_that.justDeclined,_that.since);case ConsentBusy() when busy != null:
return busy();case ConsentFailure() when failure != null:
return failure();case ConsentWriteFailure() when writeFailure != null:
return writeFailure();case ConsentWithdrawFailure() when withdrawFailure != null:
return withdrawFailure();case _:
  return null;

}
}

}

/// @nodoc


class ConsentUnknown implements ConsentState {
  const ConsentUnknown();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConsentUnknown);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ConsentState.unknown()';
}


}




/// @nodoc


class ConsentKnown implements ConsentState {
  const ConsentKnown({required this.granted, this.justDeclined = false, this.since});
  

 final  bool granted;
@JsonKey() final  bool justDeclined;
 final  DateTime? since;

/// Create a copy of ConsentState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConsentKnownCopyWith<ConsentKnown> get copyWith => _$ConsentKnownCopyWithImpl<ConsentKnown>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConsentKnown&&(identical(other.granted, granted) || other.granted == granted)&&(identical(other.justDeclined, justDeclined) || other.justDeclined == justDeclined)&&(identical(other.since, since) || other.since == since));
}


@override
int get hashCode {
    return Object.hash(runtimeType,granted,justDeclined,since);
}

@override
String toString() {
    return 'ConsentState.known(granted: $granted, justDeclined: $justDeclined, since: $since)';
}


}

/// @nodoc
abstract mixin class $ConsentKnownCopyWith<$Res> implements $ConsentStateCopyWith<$Res> {
  factory $ConsentKnownCopyWith(ConsentKnown value, $Res Function(ConsentKnown) _then) = _$ConsentKnownCopyWithImpl;
@useResult
$Res call({
 bool granted, bool justDeclined, DateTime? since
});




}
/// @nodoc
class _$ConsentKnownCopyWithImpl<$Res>
    implements $ConsentKnownCopyWith<$Res> {
  _$ConsentKnownCopyWithImpl(this._self, this._then);

  final ConsentKnown _self;
  final $Res Function(ConsentKnown) _then;

/// Create a copy of ConsentState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? granted = null,Object? justDeclined = null,Object? since = freezed,}) {
  return _then(ConsentKnown(
granted: null == granted ? _self.granted : granted // ignore: cast_nullable_to_non_nullable
as bool,justDeclined: null == justDeclined ? _self.justDeclined : justDeclined // ignore: cast_nullable_to_non_nullable
as bool,since: freezed == since ? _self.since : since // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc


class ConsentBusy implements ConsentState {
  const ConsentBusy();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConsentBusy);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ConsentState.busy()';
}


}




/// @nodoc


class ConsentFailure implements ConsentState {
  const ConsentFailure();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConsentFailure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ConsentState.failure()';
}


}




/// @nodoc


class ConsentWriteFailure implements ConsentState {
  const ConsentWriteFailure();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConsentWriteFailure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ConsentState.writeFailure()';
}


}




/// @nodoc


class ConsentWithdrawFailure implements ConsentState {
  const ConsentWithdrawFailure();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConsentWithdrawFailure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ConsentState.withdrawFailure()';
}


}




// dart format on
