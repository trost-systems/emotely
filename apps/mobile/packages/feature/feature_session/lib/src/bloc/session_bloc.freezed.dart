// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionEvent {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SessionEvent()';
}


}

/// @nodoc
class $SessionEventCopyWith<$Res>  {
$SessionEventCopyWith(SessionEvent _, $Res Function(SessionEvent) __);
}


/// Adds pattern-matching-related methods to [SessionEvent].
extension SessionEventPatterns on SessionEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SessionStarted value)?  started,TResult Function( SessionAnswered value)?  answered,TResult Function( SessionRetried value)?  retried,TResult Function( SessionRestarted value)?  restarted,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SessionStarted() when started != null:
return started(_that);case SessionAnswered() when answered != null:
return answered(_that);case SessionRetried() when retried != null:
return retried(_that);case SessionRestarted() when restarted != null:
return restarted(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SessionStarted value)  started,required TResult Function( SessionAnswered value)  answered,required TResult Function( SessionRetried value)  retried,required TResult Function( SessionRestarted value)  restarted,}){
final _that = this;
switch (_that) {
case SessionStarted():
return started(_that);case SessionAnswered():
return answered(_that);case SessionRetried():
return retried(_that);case SessionRestarted():
return restarted(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SessionStarted value)?  started,TResult? Function( SessionAnswered value)?  answered,TResult? Function( SessionRetried value)?  retried,TResult? Function( SessionRestarted value)?  restarted,}){
final _that = this;
switch (_that) {
case SessionStarted() when started != null:
return started(_that);case SessionAnswered() when answered != null:
return answered(_that);case SessionRetried() when retried != null:
return retried(_that);case SessionRestarted() when restarted != null:
return restarted(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( Locale locale,  String? resume)?  started,TResult Function( Answer answer)?  answered,TResult Function()?  retried,TResult Function()?  restarted,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SessionStarted() when started != null:
return started(_that.locale,_that.resume);case SessionAnswered() when answered != null:
return answered(_that.answer);case SessionRetried() when retried != null:
return retried();case SessionRestarted() when restarted != null:
return restarted();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( Locale locale,  String? resume)  started,required TResult Function( Answer answer)  answered,required TResult Function()  retried,required TResult Function()  restarted,}) {final _that = this;
switch (_that) {
case SessionStarted():
return started(_that.locale,_that.resume);case SessionAnswered():
return answered(_that.answer);case SessionRetried():
return retried();case SessionRestarted():
return restarted();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( Locale locale,  String? resume)?  started,TResult? Function( Answer answer)?  answered,TResult? Function()?  retried,TResult? Function()?  restarted,}) {final _that = this;
switch (_that) {
case SessionStarted() when started != null:
return started(_that.locale,_that.resume);case SessionAnswered() when answered != null:
return answered(_that.answer);case SessionRetried() when retried != null:
return retried();case SessionRestarted() when restarted != null:
return restarted();case _:
  return null;

}
}

}

/// @nodoc


class SessionStarted implements SessionEvent {
  const SessionStarted({required this.locale, this.resume});
  

 final  Locale locale;
 final  String? resume;

/// Create a copy of SessionEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionStartedCopyWith<SessionStarted> get copyWith => _$SessionStartedCopyWithImpl<SessionStarted>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionStarted&&(identical(other.locale, locale) || other.locale == locale)&&(identical(other.resume, resume) || other.resume == resume));
}


@override
int get hashCode {
    return Object.hash(runtimeType,locale,resume);
}

@override
String toString() {
    return 'SessionEvent.started(locale: $locale, resume: $resume)';
}


}

/// @nodoc
abstract mixin class $SessionStartedCopyWith<$Res> implements $SessionEventCopyWith<$Res> {
  factory $SessionStartedCopyWith(SessionStarted value, $Res Function(SessionStarted) _then) = _$SessionStartedCopyWithImpl;
@useResult
$Res call({
 Locale locale, String? resume
});




}
/// @nodoc
class _$SessionStartedCopyWithImpl<$Res>
    implements $SessionStartedCopyWith<$Res> {
  _$SessionStartedCopyWithImpl(this._self, this._then);

  final SessionStarted _self;
  final $Res Function(SessionStarted) _then;

/// Create a copy of SessionEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? locale = null,Object? resume = freezed,}) {
  return _then(SessionStarted(
locale: null == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as Locale,resume: freezed == resume ? _self.resume : resume // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class SessionAnswered implements SessionEvent {
  const SessionAnswered(this.answer);
  

 final  Answer answer;

/// Create a copy of SessionEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionAnsweredCopyWith<SessionAnswered> get copyWith => _$SessionAnsweredCopyWithImpl<SessionAnswered>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionAnswered&&(identical(other.answer, answer) || other.answer == answer));
}


@override
int get hashCode {
    return Object.hash(runtimeType,answer);
}

@override
String toString() {
    return 'SessionEvent.answered(answer: $answer)';
}


}

/// @nodoc
abstract mixin class $SessionAnsweredCopyWith<$Res> implements $SessionEventCopyWith<$Res> {
  factory $SessionAnsweredCopyWith(SessionAnswered value, $Res Function(SessionAnswered) _then) = _$SessionAnsweredCopyWithImpl;
@useResult
$Res call({
 Answer answer
});


$AnswerCopyWith<$Res> get answer;

}
/// @nodoc
class _$SessionAnsweredCopyWithImpl<$Res>
    implements $SessionAnsweredCopyWith<$Res> {
  _$SessionAnsweredCopyWithImpl(this._self, this._then);

  final SessionAnswered _self;
  final $Res Function(SessionAnswered) _then;

/// Create a copy of SessionEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? answer = null,}) {
  return _then(SessionAnswered(
null == answer ? _self.answer : answer // ignore: cast_nullable_to_non_nullable
as Answer,
  ));
}

/// Create a copy of SessionEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AnswerCopyWith<$Res> get answer {
  
  return $AnswerCopyWith<$Res>(_self.answer, (value) {
    return _then(_self.copyWith(answer: value));
  });
}
}

/// @nodoc


class SessionRetried implements SessionEvent {
  const SessionRetried();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionRetried);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SessionEvent.retried()';
}


}




/// @nodoc


class SessionRestarted implements SessionEvent {
  const SessionRestarted();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionRestarted);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SessionEvent.restarted()';
}


}




/// @nodoc
mixin _$SessionState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SessionState()';
}


}

/// @nodoc
class $SessionStateCopyWith<$Res>  {
$SessionStateCopyWith(SessionState _, $Res Function(SessionState) __);
}


/// Adds pattern-matching-related methods to [SessionState].
extension SessionStatePatterns on SessionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SessionInitial value)?  initial,TResult Function( SessionLoading value)?  loading,TResult Function( SessionAwaitingAnswer value)?  awaitingAnswer,TResult Function( SessionCompleted value)?  completed,TResult Function( SessionFailure value)?  failure,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SessionInitial() when initial != null:
return initial(_that);case SessionLoading() when loading != null:
return loading(_that);case SessionAwaitingAnswer() when awaitingAnswer != null:
return awaitingAnswer(_that);case SessionCompleted() when completed != null:
return completed(_that);case SessionFailure() when failure != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SessionInitial value)  initial,required TResult Function( SessionLoading value)  loading,required TResult Function( SessionAwaitingAnswer value)  awaitingAnswer,required TResult Function( SessionCompleted value)  completed,required TResult Function( SessionFailure value)  failure,}){
final _that = this;
switch (_that) {
case SessionInitial():
return initial(_that);case SessionLoading():
return loading(_that);case SessionAwaitingAnswer():
return awaitingAnswer(_that);case SessionCompleted():
return completed(_that);case SessionFailure():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SessionInitial value)?  initial,TResult? Function( SessionLoading value)?  loading,TResult? Function( SessionAwaitingAnswer value)?  awaitingAnswer,TResult? Function( SessionCompleted value)?  completed,TResult? Function( SessionFailure value)?  failure,}){
final _that = this;
switch (_that) {
case SessionInitial() when initial != null:
return initial(_that);case SessionLoading() when loading != null:
return loading(_that);case SessionAwaitingAnswer() when awaitingAnswer != null:
return awaitingAnswer(_that);case SessionCompleted() when completed != null:
return completed(_that);case SessionFailure() when failure != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  initial,TResult Function( int answered)?  loading,TResult Function( PendingQuestion pending,  int answered)?  awaitingAnswer,TResult Function( JournalEntry entry,  Map<String, AskQuestion> questions)?  completed,TResult Function( SessionFailureReason reason)?  failure,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SessionInitial() when initial != null:
return initial();case SessionLoading() when loading != null:
return loading(_that.answered);case SessionAwaitingAnswer() when awaitingAnswer != null:
return awaitingAnswer(_that.pending,_that.answered);case SessionCompleted() when completed != null:
return completed(_that.entry,_that.questions);case SessionFailure() when failure != null:
return failure(_that.reason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  initial,required TResult Function( int answered)  loading,required TResult Function( PendingQuestion pending,  int answered)  awaitingAnswer,required TResult Function( JournalEntry entry,  Map<String, AskQuestion> questions)  completed,required TResult Function( SessionFailureReason reason)  failure,}) {final _that = this;
switch (_that) {
case SessionInitial():
return initial();case SessionLoading():
return loading(_that.answered);case SessionAwaitingAnswer():
return awaitingAnswer(_that.pending,_that.answered);case SessionCompleted():
return completed(_that.entry,_that.questions);case SessionFailure():
return failure(_that.reason);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  initial,TResult? Function( int answered)?  loading,TResult? Function( PendingQuestion pending,  int answered)?  awaitingAnswer,TResult? Function( JournalEntry entry,  Map<String, AskQuestion> questions)?  completed,TResult? Function( SessionFailureReason reason)?  failure,}) {final _that = this;
switch (_that) {
case SessionInitial() when initial != null:
return initial();case SessionLoading() when loading != null:
return loading(_that.answered);case SessionAwaitingAnswer() when awaitingAnswer != null:
return awaitingAnswer(_that.pending,_that.answered);case SessionCompleted() when completed != null:
return completed(_that.entry,_that.questions);case SessionFailure() when failure != null:
return failure(_that.reason);case _:
  return null;

}
}

}

/// @nodoc


class SessionInitial implements SessionState {
  const SessionInitial();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionInitial);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SessionState.initial()';
}


}




/// @nodoc


class SessionLoading implements SessionState {
  const SessionLoading({required this.answered});
  

 final  int answered;

/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionLoadingCopyWith<SessionLoading> get copyWith => _$SessionLoadingCopyWithImpl<SessionLoading>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionLoading&&(identical(other.answered, answered) || other.answered == answered));
}


@override
int get hashCode {
    return Object.hash(runtimeType,answered);
}

@override
String toString() {
    return 'SessionState.loading(answered: $answered)';
}


}

/// @nodoc
abstract mixin class $SessionLoadingCopyWith<$Res> implements $SessionStateCopyWith<$Res> {
  factory $SessionLoadingCopyWith(SessionLoading value, $Res Function(SessionLoading) _then) = _$SessionLoadingCopyWithImpl;
@useResult
$Res call({
 int answered
});




}
/// @nodoc
class _$SessionLoadingCopyWithImpl<$Res>
    implements $SessionLoadingCopyWith<$Res> {
  _$SessionLoadingCopyWithImpl(this._self, this._then);

  final SessionLoading _self;
  final $Res Function(SessionLoading) _then;

/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? answered = null,}) {
  return _then(SessionLoading(
answered: null == answered ? _self.answered : answered // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class SessionAwaitingAnswer implements SessionState {
  const SessionAwaitingAnswer({required this.pending, required this.answered});
  

 final  PendingQuestion pending;
 final  int answered;

/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionAwaitingAnswerCopyWith<SessionAwaitingAnswer> get copyWith => _$SessionAwaitingAnswerCopyWithImpl<SessionAwaitingAnswer>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionAwaitingAnswer&&(identical(other.pending, pending) || other.pending == pending)&&(identical(other.answered, answered) || other.answered == answered));
}


@override
int get hashCode {
    return Object.hash(runtimeType,pending,answered);
}

@override
String toString() {
    return 'SessionState.awaitingAnswer(pending: $pending, answered: $answered)';
}


}

/// @nodoc
abstract mixin class $SessionAwaitingAnswerCopyWith<$Res> implements $SessionStateCopyWith<$Res> {
  factory $SessionAwaitingAnswerCopyWith(SessionAwaitingAnswer value, $Res Function(SessionAwaitingAnswer) _then) = _$SessionAwaitingAnswerCopyWithImpl;
@useResult
$Res call({
 PendingQuestion pending, int answered
});


$PendingQuestionCopyWith<$Res> get pending;

}
/// @nodoc
class _$SessionAwaitingAnswerCopyWithImpl<$Res>
    implements $SessionAwaitingAnswerCopyWith<$Res> {
  _$SessionAwaitingAnswerCopyWithImpl(this._self, this._then);

  final SessionAwaitingAnswer _self;
  final $Res Function(SessionAwaitingAnswer) _then;

/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pending = null,Object? answered = null,}) {
  return _then(SessionAwaitingAnswer(
pending: null == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as PendingQuestion,answered: null == answered ? _self.answered : answered // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PendingQuestionCopyWith<$Res> get pending {
  
  return $PendingQuestionCopyWith<$Res>(_self.pending, (value) {
    return _then(_self.copyWith(pending: value));
  });
}
}

/// @nodoc


class SessionCompleted implements SessionState {
  const SessionCompleted({required this.entry, required  Map<String, AskQuestion> questions}): _questions = questions;
  

 final  JournalEntry entry;
 final  Map<String, AskQuestion> _questions;
 Map<String, AskQuestion> get questions {
  if (_questions is EqualUnmodifiableMapView) return _questions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_questions);
}


/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionCompletedCopyWith<SessionCompleted> get copyWith => _$SessionCompletedCopyWithImpl<SessionCompleted>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionCompleted&&(identical(other.entry, entry) || other.entry == entry)&&const DeepCollectionEquality().equals(other.questions, _questions));
}


@override
int get hashCode {
    return Object.hash(runtimeType,entry,const DeepCollectionEquality().hash(_questions));
}

@override
String toString() {
    return 'SessionState.completed(entry: $entry, questions: $questions)';
}


}

/// @nodoc
abstract mixin class $SessionCompletedCopyWith<$Res> implements $SessionStateCopyWith<$Res> {
  factory $SessionCompletedCopyWith(SessionCompleted value, $Res Function(SessionCompleted) _then) = _$SessionCompletedCopyWithImpl;
@useResult
$Res call({
 JournalEntry entry, Map<String, AskQuestion> questions
});


$JournalEntryCopyWith<$Res> get entry;

}
/// @nodoc
class _$SessionCompletedCopyWithImpl<$Res>
    implements $SessionCompletedCopyWith<$Res> {
  _$SessionCompletedCopyWithImpl(this._self, this._then);

  final SessionCompleted _self;
  final $Res Function(SessionCompleted) _then;

/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? entry = null,Object? questions = null,}) {
  return _then(SessionCompleted(
entry: null == entry ? _self.entry : entry // ignore: cast_nullable_to_non_nullable
as JournalEntry,questions: null == questions ? _self._questions : questions // ignore: cast_nullable_to_non_nullable
as Map<String, AskQuestion>,
  ));
}

/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$JournalEntryCopyWith<$Res> get entry {
  
  return $JournalEntryCopyWith<$Res>(_self.entry, (value) {
    return _then(_self.copyWith(entry: value));
  });
}
}

/// @nodoc


class SessionFailure implements SessionState {
  const SessionFailure({required this.reason});
  

 final  SessionFailureReason reason;

/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionFailureCopyWith<SessionFailure> get copyWith => _$SessionFailureCopyWithImpl<SessionFailure>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionFailure&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode {
    return Object.hash(runtimeType,reason);
}

@override
String toString() {
    return 'SessionState.failure(reason: $reason)';
}


}

/// @nodoc
abstract mixin class $SessionFailureCopyWith<$Res> implements $SessionStateCopyWith<$Res> {
  factory $SessionFailureCopyWith(SessionFailure value, $Res Function(SessionFailure) _then) = _$SessionFailureCopyWithImpl;
@useResult
$Res call({
 SessionFailureReason reason
});




}
/// @nodoc
class _$SessionFailureCopyWithImpl<$Res>
    implements $SessionFailureCopyWith<$Res> {
  _$SessionFailureCopyWithImpl(this._self, this._then);

  final SessionFailure _self;
  final $Res Function(SessionFailure) _then;

/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,}) {
  return _then(SessionFailure(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as SessionFailureReason,
  ));
}


}

// dart format on
