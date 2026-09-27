// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'journal_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$JournalEvent {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is JournalEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'JournalEvent()';
}


}

/// @nodoc
class $JournalEventCopyWith<$Res>  {
$JournalEventCopyWith(JournalEvent _, $Res Function(JournalEvent) __);
}


/// Adds pattern-matching-related methods to [JournalEvent].
extension JournalEventPatterns on JournalEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( JournalLoaded value)?  loaded,TResult Function( JournalSessionDiscarded value)?  sessionDiscarded,TResult Function( JournalEntryOpened value)?  entryOpened,required TResult orElse(),}){
final _that = this;
switch (_that) {
case JournalLoaded() when loaded != null:
return loaded(_that);case JournalSessionDiscarded() when sessionDiscarded != null:
return sessionDiscarded(_that);case JournalEntryOpened() when entryOpened != null:
return entryOpened(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( JournalLoaded value)  loaded,required TResult Function( JournalSessionDiscarded value)  sessionDiscarded,required TResult Function( JournalEntryOpened value)  entryOpened,}){
final _that = this;
switch (_that) {
case JournalLoaded():
return loaded(_that);case JournalSessionDiscarded():
return sessionDiscarded(_that);case JournalEntryOpened():
return entryOpened(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( JournalLoaded value)?  loaded,TResult? Function( JournalSessionDiscarded value)?  sessionDiscarded,TResult? Function( JournalEntryOpened value)?  entryOpened,}){
final _that = this;
switch (_that) {
case JournalLoaded() when loaded != null:
return loaded(_that);case JournalSessionDiscarded() when sessionDiscarded != null:
return sessionDiscarded(_that);case JournalEntryOpened() when entryOpened != null:
return entryOpened(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  loaded,TResult Function()?  sessionDiscarded,TResult Function()?  entryOpened,required TResult orElse(),}) {final _that = this;
switch (_that) {
case JournalLoaded() when loaded != null:
return loaded();case JournalSessionDiscarded() when sessionDiscarded != null:
return sessionDiscarded();case JournalEntryOpened() when entryOpened != null:
return entryOpened();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  loaded,required TResult Function()  sessionDiscarded,required TResult Function()  entryOpened,}) {final _that = this;
switch (_that) {
case JournalLoaded():
return loaded();case JournalSessionDiscarded():
return sessionDiscarded();case JournalEntryOpened():
return entryOpened();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  loaded,TResult? Function()?  sessionDiscarded,TResult? Function()?  entryOpened,}) {final _that = this;
switch (_that) {
case JournalLoaded() when loaded != null:
return loaded();case JournalSessionDiscarded() when sessionDiscarded != null:
return sessionDiscarded();case JournalEntryOpened() when entryOpened != null:
return entryOpened();case _:
  return null;

}
}

}

/// @nodoc


class JournalLoaded implements JournalEvent {
  const JournalLoaded();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is JournalLoaded);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'JournalEvent.loaded()';
}


}




/// @nodoc


class JournalSessionDiscarded implements JournalEvent {
  const JournalSessionDiscarded();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is JournalSessionDiscarded);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'JournalEvent.sessionDiscarded()';
}


}




/// @nodoc


class JournalEntryOpened implements JournalEvent {
  const JournalEntryOpened();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is JournalEntryOpened);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'JournalEvent.entryOpened()';
}


}




/// @nodoc
mixin _$JournalState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is JournalState);
}


@override
int get hashCode => runtimeType.hashCode;



}

/// @nodoc
class $JournalStateCopyWith<$Res>  {
$JournalStateCopyWith(JournalState _, $Res Function(JournalState) __);
}


/// Adds pattern-matching-related methods to [JournalState].
extension JournalStatePatterns on JournalState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( JournalLoading value)?  loading,TResult Function( JournalReady value)?  ready,TResult Function( JournalFailure value)?  failure,required TResult orElse(),}){
final _that = this;
switch (_that) {
case JournalLoading() when loading != null:
return loading(_that);case JournalReady() when ready != null:
return ready(_that);case JournalFailure() when failure != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( JournalLoading value)  loading,required TResult Function( JournalReady value)  ready,required TResult Function( JournalFailure value)  failure,}){
final _that = this;
switch (_that) {
case JournalLoading():
return loading(_that);case JournalReady():
return ready(_that);case JournalFailure():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( JournalLoading value)?  loading,TResult? Function( JournalReady value)?  ready,TResult? Function( JournalFailure value)?  failure,}){
final _that = this;
switch (_that) {
case JournalLoading() when loading != null:
return loading(_that);case JournalReady() when ready != null:
return ready(_that);case JournalFailure() when failure != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  loading,TResult Function( List<EntryRecord> entries,  DateTime now,  OpenSession? openSession,  String? displayName)?  ready,TResult Function()?  failure,required TResult orElse(),}) {final _that = this;
switch (_that) {
case JournalLoading() when loading != null:
return loading();case JournalReady() when ready != null:
return ready(_that.entries,_that.now,_that.openSession,_that.displayName);case JournalFailure() when failure != null:
return failure();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  loading,required TResult Function( List<EntryRecord> entries,  DateTime now,  OpenSession? openSession,  String? displayName)  ready,required TResult Function()  failure,}) {final _that = this;
switch (_that) {
case JournalLoading():
return loading();case JournalReady():
return ready(_that.entries,_that.now,_that.openSession,_that.displayName);case JournalFailure():
return failure();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  loading,TResult? Function( List<EntryRecord> entries,  DateTime now,  OpenSession? openSession,  String? displayName)?  ready,TResult? Function()?  failure,}) {final _that = this;
switch (_that) {
case JournalLoading() when loading != null:
return loading();case JournalReady() when ready != null:
return ready(_that.entries,_that.now,_that.openSession,_that.displayName);case JournalFailure() when failure != null:
return failure();case _:
  return null;

}
}

}

/// @nodoc


class JournalLoading implements JournalState {
  const JournalLoading();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is JournalLoading);
}


@override
int get hashCode => runtimeType.hashCode;



}




/// @nodoc


class JournalReady implements JournalState {
  const JournalReady({required  List<EntryRecord> entries, required this.now, this.openSession, this.displayName}): _entries = entries;
  

 final  List<EntryRecord> _entries;
 List<EntryRecord> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}

 final  DateTime now;
 final  OpenSession? openSession;
 final  String? displayName;

/// Create a copy of JournalState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JournalReadyCopyWith<JournalReady> get copyWith => _$JournalReadyCopyWithImpl<JournalReady>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is JournalReady&&const DeepCollectionEquality().equals(other.entries, _entries)&&(identical(other.now, now) || other.now == now)&&(identical(other.openSession, openSession) || other.openSession == openSession)&&(identical(other.displayName, displayName) || other.displayName == displayName));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_entries),now,openSession,displayName);
}



}

/// @nodoc
abstract mixin class $JournalReadyCopyWith<$Res> implements $JournalStateCopyWith<$Res> {
  factory $JournalReadyCopyWith(JournalReady value, $Res Function(JournalReady) _then) = _$JournalReadyCopyWithImpl;
@useResult
$Res call({
 List<EntryRecord> entries, DateTime now, OpenSession? openSession, String? displayName
});


$OpenSessionCopyWith<$Res>? get openSession;

}
/// @nodoc
class _$JournalReadyCopyWithImpl<$Res>
    implements $JournalReadyCopyWith<$Res> {
  _$JournalReadyCopyWithImpl(this._self, this._then);

  final JournalReady _self;
  final $Res Function(JournalReady) _then;

/// Create a copy of JournalState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? entries = null,Object? now = null,Object? openSession = freezed,Object? displayName = freezed,}) {
  return _then(JournalReady(
entries: null == entries ? _self._entries : entries // ignore: cast_nullable_to_non_nullable
as List<EntryRecord>,now: null == now ? _self.now : now // ignore: cast_nullable_to_non_nullable
as DateTime,openSession: freezed == openSession ? _self.openSession : openSession // ignore: cast_nullable_to_non_nullable
as OpenSession?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of JournalState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OpenSessionCopyWith<$Res>? get openSession {
    if (_self.openSession == null) {
    return null;
  }

  return $OpenSessionCopyWith<$Res>(_self.openSession!, (value) {
    return _then(_self.copyWith(openSession: value));
  });
}
}

/// @nodoc


class JournalFailure implements JournalState {
  const JournalFailure();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is JournalFailure);
}


@override
int get hashCode => runtimeType.hashCode;



}




// dart format on
