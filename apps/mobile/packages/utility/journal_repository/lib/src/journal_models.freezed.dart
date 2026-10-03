// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'journal_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OpenSession {

 String get id; List<Object?> get transcript; String get signature; List<AskQuestion> get questions; PendingQuestion? get pending;
/// Create a copy of OpenSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OpenSessionCopyWith<OpenSession> get copyWith => _$OpenSessionCopyWithImpl<OpenSession>(this as OpenSession, _$identity);

  /// Serializes this OpenSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as OpenSession;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OpenSession&&(identical(other.id, _this.id) || other.id == _this.id)&&const DeepCollectionEquality().equals(other.transcript, _this.transcript)&&(identical(other.signature, _this.signature) || other.signature == _this.signature)&&const DeepCollectionEquality().equals(other.questions, _this.questions)&&(identical(other.pending, _this.pending) || other.pending == _this.pending));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as OpenSession;
  return Object.hash(runtimeType,_this.id,const DeepCollectionEquality().hash(_this.transcript),_this.signature,const DeepCollectionEquality().hash(_this.questions),_this.pending);
}

@override
String toString() {
  final _this = this as OpenSession;
  return 'OpenSession(id: ${_this.id}, transcript: ${_this.transcript}, signature: ${_this.signature}, questions: ${_this.questions}, pending: ${_this.pending})';
}


}

/// @nodoc
abstract mixin class $OpenSessionCopyWith<$Res>  {
  factory $OpenSessionCopyWith(OpenSession value, $Res Function(OpenSession) _then) = _$OpenSessionCopyWithImpl;
@useResult
$Res call({
 String id, List<Object?> transcript, String signature, List<AskQuestion> questions, PendingQuestion? pending
});


$PendingQuestionCopyWith<$Res>? get pending;

}
/// @nodoc
class _$OpenSessionCopyWithImpl<$Res>
    implements $OpenSessionCopyWith<$Res> {
  _$OpenSessionCopyWithImpl(this._self, this._then);

  final OpenSession _self;
  final $Res Function(OpenSession) _then;

/// Create a copy of OpenSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? transcript = null,Object? signature = null,Object? questions = null,Object? pending = freezed,}) {
  return _then(OpenSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,transcript: null == transcript ? _self.transcript : transcript // ignore: cast_nullable_to_non_nullable
as List<Object?>,signature: null == signature ? _self.signature : signature // ignore: cast_nullable_to_non_nullable
as String,questions: null == questions ? _self.questions : questions // ignore: cast_nullable_to_non_nullable
as List<AskQuestion>,pending: freezed == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as PendingQuestion?,
  ));
}
/// Create a copy of OpenSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PendingQuestionCopyWith<$Res>? get pending {
    if (_self.pending == null) {
    return null;
  }

  return $PendingQuestionCopyWith<$Res>(_self.pending!, (value) {
    return _then(_self.copyWith(pending: value));
  });
}
}


/// Adds pattern-matching-related methods to [OpenSession].
extension OpenSessionPatterns on OpenSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OpenSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OpenSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OpenSession value)  $default,){
final _that = this;
switch (_that) {
case _OpenSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OpenSession value)?  $default,){
final _that = this;
switch (_that) {
case _OpenSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  List<Object?> transcript,  String signature,  List<AskQuestion> questions,  PendingQuestion? pending)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OpenSession() when $default != null:
return $default(_that.id,_that.transcript,_that.signature,_that.questions,_that.pending);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  List<Object?> transcript,  String signature,  List<AskQuestion> questions,  PendingQuestion? pending)  $default,) {final _that = this;
switch (_that) {
case _OpenSession():
return $default(_that.id,_that.transcript,_that.signature,_that.questions,_that.pending);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  List<Object?> transcript,  String signature,  List<AskQuestion> questions,  PendingQuestion? pending)?  $default,) {final _that = this;
switch (_that) {
case _OpenSession() when $default != null:
return $default(_that.id,_that.transcript,_that.signature,_that.questions,_that.pending);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OpenSession implements OpenSession {
  const _OpenSession({required this.id, required  List<Object?> transcript, required this.signature, required  List<AskQuestion> questions, this.pending}): _transcript = transcript,_questions = questions;
  factory _OpenSession.fromJson(Map<String, dynamic> json) => _$OpenSessionFromJson(json);

@override final  String id;
 final  List<Object?> _transcript;
@override List<Object?> get transcript {
  if (_transcript is EqualUnmodifiableListView) return _transcript;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_transcript);
}

@override final  String signature;
 final  List<AskQuestion> _questions;
@override List<AskQuestion> get questions {
  if (_questions is EqualUnmodifiableListView) return _questions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_questions);
}

@override final  PendingQuestion? pending;

/// Create a copy of OpenSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OpenSessionCopyWith<_OpenSession> get copyWith => __$OpenSessionCopyWithImpl<_OpenSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OpenSessionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OpenSession&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.transcript, _transcript)&&(identical(other.signature, signature) || other.signature == signature)&&const DeepCollectionEquality().equals(other.questions, _questions)&&(identical(other.pending, pending) || other.pending == pending));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,const DeepCollectionEquality().hash(_transcript),signature,const DeepCollectionEquality().hash(_questions),pending);
}

@override
String toString() {
    return 'OpenSession(id: $id, transcript: $transcript, signature: $signature, questions: $questions, pending: $pending)';
}


}

/// @nodoc
abstract mixin class _$OpenSessionCopyWith<$Res> implements $OpenSessionCopyWith<$Res> {
  factory _$OpenSessionCopyWith(_OpenSession value, $Res Function(_OpenSession) _then) = __$OpenSessionCopyWithImpl;
@override @useResult
$Res call({
 String id, List<Object?> transcript, String signature, List<AskQuestion> questions, PendingQuestion? pending
});


@override $PendingQuestionCopyWith<$Res>? get pending;

}
/// @nodoc
class __$OpenSessionCopyWithImpl<$Res>
    implements _$OpenSessionCopyWith<$Res> {
  __$OpenSessionCopyWithImpl(this._self, this._then);

  final _OpenSession _self;
  final $Res Function(_OpenSession) _then;

/// Create a copy of OpenSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? transcript = null,Object? signature = null,Object? questions = null,Object? pending = freezed,}) {
  return _then(_OpenSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,transcript: null == transcript ? _self._transcript : transcript // ignore: cast_nullable_to_non_nullable
as List<Object?>,signature: null == signature ? _self.signature : signature // ignore: cast_nullable_to_non_nullable
as String,questions: null == questions ? _self._questions : questions // ignore: cast_nullable_to_non_nullable
as List<AskQuestion>,pending: freezed == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as PendingQuestion?,
  ));
}

/// Create a copy of OpenSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PendingQuestionCopyWith<$Res>? get pending {
    if (_self.pending == null) {
    return null;
  }

  return $PendingQuestionCopyWith<$Res>(_self.pending!, (value) {
    return _then(_self.copyWith(pending: value));
  });
}
}


/// @nodoc
mixin _$EntryRecord {

 String get id; String get summary; Map<String, Answer> get answers; List<AskQuestion> get questions; DateTime get journalDay; DateTime get createdAt;
/// Create a copy of EntryRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EntryRecordCopyWith<EntryRecord> get copyWith => _$EntryRecordCopyWithImpl<EntryRecord>(this as EntryRecord, _$identity);

  /// Serializes this EntryRecord to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as EntryRecord;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EntryRecord&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.summary, _this.summary) || other.summary == _this.summary)&&const DeepCollectionEquality().equals(other.answers, _this.answers)&&const DeepCollectionEquality().equals(other.questions, _this.questions)&&(identical(other.journalDay, _this.journalDay) || other.journalDay == _this.journalDay)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as EntryRecord;
  return Object.hash(runtimeType,_this.id,_this.summary,const DeepCollectionEquality().hash(_this.answers),const DeepCollectionEquality().hash(_this.questions),_this.journalDay,_this.createdAt);
}

@override
String toString() {
  final _this = this as EntryRecord;
  return 'EntryRecord(id: ${_this.id}, summary: ${_this.summary}, answers: ${_this.answers}, questions: ${_this.questions}, journalDay: ${_this.journalDay}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $EntryRecordCopyWith<$Res>  {
  factory $EntryRecordCopyWith(EntryRecord value, $Res Function(EntryRecord) _then) = _$EntryRecordCopyWithImpl;
@useResult
$Res call({
 String id, String summary, Map<String, Answer> answers, List<AskQuestion> questions, DateTime journalDay, DateTime createdAt
});




}
/// @nodoc
class _$EntryRecordCopyWithImpl<$Res>
    implements $EntryRecordCopyWith<$Res> {
  _$EntryRecordCopyWithImpl(this._self, this._then);

  final EntryRecord _self;
  final $Res Function(EntryRecord) _then;

/// Create a copy of EntryRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? summary = null,Object? answers = null,Object? questions = null,Object? journalDay = null,Object? createdAt = null,}) {
  return _then(EntryRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,answers: null == answers ? _self.answers : answers // ignore: cast_nullable_to_non_nullable
as Map<String, Answer>,questions: null == questions ? _self.questions : questions // ignore: cast_nullable_to_non_nullable
as List<AskQuestion>,journalDay: null == journalDay ? _self.journalDay : journalDay // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [EntryRecord].
extension EntryRecordPatterns on EntryRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EntryRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EntryRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EntryRecord value)  $default,){
final _that = this;
switch (_that) {
case _EntryRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EntryRecord value)?  $default,){
final _that = this;
switch (_that) {
case _EntryRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String summary,  Map<String, Answer> answers,  List<AskQuestion> questions,  DateTime journalDay,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EntryRecord() when $default != null:
return $default(_that.id,_that.summary,_that.answers,_that.questions,_that.journalDay,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String summary,  Map<String, Answer> answers,  List<AskQuestion> questions,  DateTime journalDay,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _EntryRecord():
return $default(_that.id,_that.summary,_that.answers,_that.questions,_that.journalDay,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String summary,  Map<String, Answer> answers,  List<AskQuestion> questions,  DateTime journalDay,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _EntryRecord() when $default != null:
return $default(_that.id,_that.summary,_that.answers,_that.questions,_that.journalDay,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EntryRecord implements EntryRecord {
  const _EntryRecord({required this.id, required this.summary, required  Map<String, Answer> answers, required  List<AskQuestion> questions, required this.journalDay, required this.createdAt}): _answers = answers,_questions = questions;
  factory _EntryRecord.fromJson(Map<String, dynamic> json) => _$EntryRecordFromJson(json);

@override final  String id;
@override final  String summary;
 final  Map<String, Answer> _answers;
@override Map<String, Answer> get answers {
  if (_answers is EqualUnmodifiableMapView) return _answers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_answers);
}

 final  List<AskQuestion> _questions;
@override List<AskQuestion> get questions {
  if (_questions is EqualUnmodifiableListView) return _questions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_questions);
}

@override final  DateTime journalDay;
@override final  DateTime createdAt;

/// Create a copy of EntryRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EntryRecordCopyWith<_EntryRecord> get copyWith => __$EntryRecordCopyWithImpl<_EntryRecord>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EntryRecordToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EntryRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.summary, summary) || other.summary == summary)&&const DeepCollectionEquality().equals(other.answers, _answers)&&const DeepCollectionEquality().equals(other.questions, _questions)&&(identical(other.journalDay, journalDay) || other.journalDay == journalDay)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,summary,const DeepCollectionEquality().hash(_answers),const DeepCollectionEquality().hash(_questions),journalDay,createdAt);
}

@override
String toString() {
    return 'EntryRecord(id: $id, summary: $summary, answers: $answers, questions: $questions, journalDay: $journalDay, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$EntryRecordCopyWith<$Res> implements $EntryRecordCopyWith<$Res> {
  factory _$EntryRecordCopyWith(_EntryRecord value, $Res Function(_EntryRecord) _then) = __$EntryRecordCopyWithImpl;
@override @useResult
$Res call({
 String id, String summary, Map<String, Answer> answers, List<AskQuestion> questions, DateTime journalDay, DateTime createdAt
});




}
/// @nodoc
class __$EntryRecordCopyWithImpl<$Res>
    implements _$EntryRecordCopyWith<$Res> {
  __$EntryRecordCopyWithImpl(this._self, this._then);

  final _EntryRecord _self;
  final $Res Function(_EntryRecord) _then;

/// Create a copy of EntryRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? summary = null,Object? answers = null,Object? questions = null,Object? journalDay = null,Object? createdAt = null,}) {
  return _then(_EntryRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,answers: null == answers ? _self._answers : answers // ignore: cast_nullable_to_non_nullable
as Map<String, Answer>,questions: null == questions ? _self._questions : questions // ignore: cast_nullable_to_non_nullable
as List<AskQuestion>,journalDay: null == journalDay ? _self.journalDay : journalDay // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
