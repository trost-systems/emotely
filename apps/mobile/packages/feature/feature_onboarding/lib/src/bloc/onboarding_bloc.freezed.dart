// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'onboarding_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$OnboardingEvent {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is OnboardingEvent);
}


@override
int get hashCode => runtimeType.hashCode;



}

/// @nodoc
class $OnboardingEventCopyWith<$Res>  {
$OnboardingEventCopyWith(OnboardingEvent _, $Res Function(OnboardingEvent) __);
}


/// Adds pattern-matching-related methods to [OnboardingEvent].
extension OnboardingEventPatterns on OnboardingEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( OnboardingStarted value)?  started,TResult Function( OnboardingNameChanged value)?  nameChanged,TResult Function( OnboardingContinued value)?  continued,TResult Function( OnboardingSkipped value)?  skipped,TResult Function( OnboardingBack value)?  back,TResult Function( OnboardingRetried value)?  retried,required TResult orElse(),}){
final _that = this;
switch (_that) {
case OnboardingStarted() when started != null:
return started(_that);case OnboardingNameChanged() when nameChanged != null:
return nameChanged(_that);case OnboardingContinued() when continued != null:
return continued(_that);case OnboardingSkipped() when skipped != null:
return skipped(_that);case OnboardingBack() when back != null:
return back(_that);case OnboardingRetried() when retried != null:
return retried(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( OnboardingStarted value)  started,required TResult Function( OnboardingNameChanged value)  nameChanged,required TResult Function( OnboardingContinued value)  continued,required TResult Function( OnboardingSkipped value)  skipped,required TResult Function( OnboardingBack value)  back,required TResult Function( OnboardingRetried value)  retried,}){
final _that = this;
switch (_that) {
case OnboardingStarted():
return started(_that);case OnboardingNameChanged():
return nameChanged(_that);case OnboardingContinued():
return continued(_that);case OnboardingSkipped():
return skipped(_that);case OnboardingBack():
return back(_that);case OnboardingRetried():
return retried(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( OnboardingStarted value)?  started,TResult? Function( OnboardingNameChanged value)?  nameChanged,TResult? Function( OnboardingContinued value)?  continued,TResult? Function( OnboardingSkipped value)?  skipped,TResult? Function( OnboardingBack value)?  back,TResult? Function( OnboardingRetried value)?  retried,}){
final _that = this;
switch (_that) {
case OnboardingStarted() when started != null:
return started(_that);case OnboardingNameChanged() when nameChanged != null:
return nameChanged(_that);case OnboardingContinued() when continued != null:
return continued(_that);case OnboardingSkipped() when skipped != null:
return skipped(_that);case OnboardingBack() when back != null:
return back(_that);case OnboardingRetried() when retried != null:
return retried(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( OnboardingPhase phase)?  started,TResult Function( String text)?  nameChanged,TResult Function( OnboardingStepId step)?  continued,TResult Function( OnboardingStepId step)?  skipped,TResult Function( OnboardingStepId step)?  back,TResult Function()?  retried,required TResult orElse(),}) {final _that = this;
switch (_that) {
case OnboardingStarted() when started != null:
return started(_that.phase);case OnboardingNameChanged() when nameChanged != null:
return nameChanged(_that.text);case OnboardingContinued() when continued != null:
return continued(_that.step);case OnboardingSkipped() when skipped != null:
return skipped(_that.step);case OnboardingBack() when back != null:
return back(_that.step);case OnboardingRetried() when retried != null:
return retried();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( OnboardingPhase phase)  started,required TResult Function( String text)  nameChanged,required TResult Function( OnboardingStepId step)  continued,required TResult Function( OnboardingStepId step)  skipped,required TResult Function( OnboardingStepId step)  back,required TResult Function()  retried,}) {final _that = this;
switch (_that) {
case OnboardingStarted():
return started(_that.phase);case OnboardingNameChanged():
return nameChanged(_that.text);case OnboardingContinued():
return continued(_that.step);case OnboardingSkipped():
return skipped(_that.step);case OnboardingBack():
return back(_that.step);case OnboardingRetried():
return retried();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( OnboardingPhase phase)?  started,TResult? Function( String text)?  nameChanged,TResult? Function( OnboardingStepId step)?  continued,TResult? Function( OnboardingStepId step)?  skipped,TResult? Function( OnboardingStepId step)?  back,TResult? Function()?  retried,}) {final _that = this;
switch (_that) {
case OnboardingStarted() when started != null:
return started(_that.phase);case OnboardingNameChanged() when nameChanged != null:
return nameChanged(_that.text);case OnboardingContinued() when continued != null:
return continued(_that.step);case OnboardingSkipped() when skipped != null:
return skipped(_that.step);case OnboardingBack() when back != null:
return back(_that.step);case OnboardingRetried() when retried != null:
return retried();case _:
  return null;

}
}

}

/// @nodoc


class OnboardingStarted implements OnboardingEvent {
  const OnboardingStarted(this.phase);
  

 final  OnboardingPhase phase;

/// Create a copy of OnboardingEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnboardingStartedCopyWith<OnboardingStarted> get copyWith => _$OnboardingStartedCopyWithImpl<OnboardingStarted>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is OnboardingStarted&&(identical(other.phase, phase) || other.phase == phase));
}


@override
int get hashCode {
    return Object.hash(runtimeType,phase);
}



}

/// @nodoc
abstract mixin class $OnboardingStartedCopyWith<$Res> implements $OnboardingEventCopyWith<$Res> {
  factory $OnboardingStartedCopyWith(OnboardingStarted value, $Res Function(OnboardingStarted) _then) = _$OnboardingStartedCopyWithImpl;
@useResult
$Res call({
 OnboardingPhase phase
});




}
/// @nodoc
class _$OnboardingStartedCopyWithImpl<$Res>
    implements $OnboardingStartedCopyWith<$Res> {
  _$OnboardingStartedCopyWithImpl(this._self, this._then);

  final OnboardingStarted _self;
  final $Res Function(OnboardingStarted) _then;

/// Create a copy of OnboardingEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? phase = null,}) {
  return _then(OnboardingStarted(
null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as OnboardingPhase,
  ));
}


}

/// @nodoc


class OnboardingNameChanged implements OnboardingEvent {
  const OnboardingNameChanged(this.text);
  

 final  String text;

/// Create a copy of OnboardingEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnboardingNameChangedCopyWith<OnboardingNameChanged> get copyWith => _$OnboardingNameChangedCopyWithImpl<OnboardingNameChanged>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is OnboardingNameChanged&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode {
    return Object.hash(runtimeType,text);
}



}

/// @nodoc
abstract mixin class $OnboardingNameChangedCopyWith<$Res> implements $OnboardingEventCopyWith<$Res> {
  factory $OnboardingNameChangedCopyWith(OnboardingNameChanged value, $Res Function(OnboardingNameChanged) _then) = _$OnboardingNameChangedCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$OnboardingNameChangedCopyWithImpl<$Res>
    implements $OnboardingNameChangedCopyWith<$Res> {
  _$OnboardingNameChangedCopyWithImpl(this._self, this._then);

  final OnboardingNameChanged _self;
  final $Res Function(OnboardingNameChanged) _then;

/// Create a copy of OnboardingEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(OnboardingNameChanged(
null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class OnboardingContinued implements OnboardingEvent {
  const OnboardingContinued(this.step);
  

 final  OnboardingStepId step;

/// Create a copy of OnboardingEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnboardingContinuedCopyWith<OnboardingContinued> get copyWith => _$OnboardingContinuedCopyWithImpl<OnboardingContinued>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is OnboardingContinued&&(identical(other.step, step) || other.step == step));
}


@override
int get hashCode {
    return Object.hash(runtimeType,step);
}



}

/// @nodoc
abstract mixin class $OnboardingContinuedCopyWith<$Res> implements $OnboardingEventCopyWith<$Res> {
  factory $OnboardingContinuedCopyWith(OnboardingContinued value, $Res Function(OnboardingContinued) _then) = _$OnboardingContinuedCopyWithImpl;
@useResult
$Res call({
 OnboardingStepId step
});




}
/// @nodoc
class _$OnboardingContinuedCopyWithImpl<$Res>
    implements $OnboardingContinuedCopyWith<$Res> {
  _$OnboardingContinuedCopyWithImpl(this._self, this._then);

  final OnboardingContinued _self;
  final $Res Function(OnboardingContinued) _then;

/// Create a copy of OnboardingEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? step = null,}) {
  return _then(OnboardingContinued(
null == step ? _self.step : step // ignore: cast_nullable_to_non_nullable
as OnboardingStepId,
  ));
}


}

/// @nodoc


class OnboardingSkipped implements OnboardingEvent {
  const OnboardingSkipped(this.step);
  

 final  OnboardingStepId step;

/// Create a copy of OnboardingEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnboardingSkippedCopyWith<OnboardingSkipped> get copyWith => _$OnboardingSkippedCopyWithImpl<OnboardingSkipped>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is OnboardingSkipped&&(identical(other.step, step) || other.step == step));
}


@override
int get hashCode {
    return Object.hash(runtimeType,step);
}



}

/// @nodoc
abstract mixin class $OnboardingSkippedCopyWith<$Res> implements $OnboardingEventCopyWith<$Res> {
  factory $OnboardingSkippedCopyWith(OnboardingSkipped value, $Res Function(OnboardingSkipped) _then) = _$OnboardingSkippedCopyWithImpl;
@useResult
$Res call({
 OnboardingStepId step
});




}
/// @nodoc
class _$OnboardingSkippedCopyWithImpl<$Res>
    implements $OnboardingSkippedCopyWith<$Res> {
  _$OnboardingSkippedCopyWithImpl(this._self, this._then);

  final OnboardingSkipped _self;
  final $Res Function(OnboardingSkipped) _then;

/// Create a copy of OnboardingEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? step = null,}) {
  return _then(OnboardingSkipped(
null == step ? _self.step : step // ignore: cast_nullable_to_non_nullable
as OnboardingStepId,
  ));
}


}

/// @nodoc


class OnboardingBack implements OnboardingEvent {
  const OnboardingBack(this.step);
  

 final  OnboardingStepId step;

/// Create a copy of OnboardingEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnboardingBackCopyWith<OnboardingBack> get copyWith => _$OnboardingBackCopyWithImpl<OnboardingBack>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is OnboardingBack&&(identical(other.step, step) || other.step == step));
}


@override
int get hashCode {
    return Object.hash(runtimeType,step);
}



}

/// @nodoc
abstract mixin class $OnboardingBackCopyWith<$Res> implements $OnboardingEventCopyWith<$Res> {
  factory $OnboardingBackCopyWith(OnboardingBack value, $Res Function(OnboardingBack) _then) = _$OnboardingBackCopyWithImpl;
@useResult
$Res call({
 OnboardingStepId step
});




}
/// @nodoc
class _$OnboardingBackCopyWithImpl<$Res>
    implements $OnboardingBackCopyWith<$Res> {
  _$OnboardingBackCopyWithImpl(this._self, this._then);

  final OnboardingBack _self;
  final $Res Function(OnboardingBack) _then;

/// Create a copy of OnboardingEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? step = null,}) {
  return _then(OnboardingBack(
null == step ? _self.step : step // ignore: cast_nullable_to_non_nullable
as OnboardingStepId,
  ));
}


}

/// @nodoc


class OnboardingRetried implements OnboardingEvent {
  const OnboardingRetried();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is OnboardingRetried);
}


@override
int get hashCode => runtimeType.hashCode;



}




/// @nodoc
mixin _$OnboardingState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is OnboardingState);
}


@override
int get hashCode => runtimeType.hashCode;



}

/// @nodoc
class $OnboardingStateCopyWith<$Res>  {
$OnboardingStateCopyWith(OnboardingState _, $Res Function(OnboardingState) __);
}


/// Adds pattern-matching-related methods to [OnboardingState].
extension OnboardingStatePatterns on OnboardingState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( OnboardingLoading value)?  loading,TResult Function( OnboardingSaving value)?  saving,TResult Function( OnboardingShowing value)?  showing,TResult Function( OnboardingSaveFailed value)?  saveFailed,TResult Function( OnboardingFinished value)?  finished,required TResult orElse(),}){
final _that = this;
switch (_that) {
case OnboardingLoading() when loading != null:
return loading(_that);case OnboardingSaving() when saving != null:
return saving(_that);case OnboardingShowing() when showing != null:
return showing(_that);case OnboardingSaveFailed() when saveFailed != null:
return saveFailed(_that);case OnboardingFinished() when finished != null:
return finished(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( OnboardingLoading value)  loading,required TResult Function( OnboardingSaving value)  saving,required TResult Function( OnboardingShowing value)  showing,required TResult Function( OnboardingSaveFailed value)  saveFailed,required TResult Function( OnboardingFinished value)  finished,}){
final _that = this;
switch (_that) {
case OnboardingLoading():
return loading(_that);case OnboardingSaving():
return saving(_that);case OnboardingShowing():
return showing(_that);case OnboardingSaveFailed():
return saveFailed(_that);case OnboardingFinished():
return finished(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( OnboardingLoading value)?  loading,TResult? Function( OnboardingSaving value)?  saving,TResult? Function( OnboardingShowing value)?  showing,TResult? Function( OnboardingSaveFailed value)?  saveFailed,TResult? Function( OnboardingFinished value)?  finished,}){
final _that = this;
switch (_that) {
case OnboardingLoading() when loading != null:
return loading(_that);case OnboardingSaving() when saving != null:
return saving(_that);case OnboardingShowing() when showing != null:
return showing(_that);case OnboardingSaveFailed() when saveFailed != null:
return saveFailed(_that);case OnboardingFinished() when finished != null:
return finished(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  loading,TResult Function()?  saving,TResult Function( OnboardingStep step,  OnboardingProgress progress,  int position,  int dots,  bool canGoBack,  DisplayNameProblem? problem)?  showing,TResult Function()?  saveFailed,TResult Function( OnboardingNext next)?  finished,required TResult orElse(),}) {final _that = this;
switch (_that) {
case OnboardingLoading() when loading != null:
return loading();case OnboardingSaving() when saving != null:
return saving();case OnboardingShowing() when showing != null:
return showing(_that.step,_that.progress,_that.position,_that.dots,_that.canGoBack,_that.problem);case OnboardingSaveFailed() when saveFailed != null:
return saveFailed();case OnboardingFinished() when finished != null:
return finished(_that.next);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  loading,required TResult Function()  saving,required TResult Function( OnboardingStep step,  OnboardingProgress progress,  int position,  int dots,  bool canGoBack,  DisplayNameProblem? problem)  showing,required TResult Function()  saveFailed,required TResult Function( OnboardingNext next)  finished,}) {final _that = this;
switch (_that) {
case OnboardingLoading():
return loading();case OnboardingSaving():
return saving();case OnboardingShowing():
return showing(_that.step,_that.progress,_that.position,_that.dots,_that.canGoBack,_that.problem);case OnboardingSaveFailed():
return saveFailed();case OnboardingFinished():
return finished(_that.next);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  loading,TResult? Function()?  saving,TResult? Function( OnboardingStep step,  OnboardingProgress progress,  int position,  int dots,  bool canGoBack,  DisplayNameProblem? problem)?  showing,TResult? Function()?  saveFailed,TResult? Function( OnboardingNext next)?  finished,}) {final _that = this;
switch (_that) {
case OnboardingLoading() when loading != null:
return loading();case OnboardingSaving() when saving != null:
return saving();case OnboardingShowing() when showing != null:
return showing(_that.step,_that.progress,_that.position,_that.dots,_that.canGoBack,_that.problem);case OnboardingSaveFailed() when saveFailed != null:
return saveFailed();case OnboardingFinished() when finished != null:
return finished(_that.next);case _:
  return null;

}
}

}

/// @nodoc


class OnboardingLoading implements OnboardingState {
  const OnboardingLoading();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is OnboardingLoading);
}


@override
int get hashCode => runtimeType.hashCode;



}




/// @nodoc


class OnboardingSaving implements OnboardingState {
  const OnboardingSaving();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is OnboardingSaving);
}


@override
int get hashCode => runtimeType.hashCode;



}




/// @nodoc


class OnboardingShowing implements OnboardingState {
  const OnboardingShowing({required this.step, required this.progress, required this.position, required this.dots, required this.canGoBack, this.problem});
  

 final  OnboardingStep step;
 final  OnboardingProgress progress;
 final  int position;
 final  int dots;
 final  bool canGoBack;
 final  DisplayNameProblem? problem;

/// Create a copy of OnboardingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnboardingShowingCopyWith<OnboardingShowing> get copyWith => _$OnboardingShowingCopyWithImpl<OnboardingShowing>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is OnboardingShowing&&(identical(other.step, step) || other.step == step)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.position, position) || other.position == position)&&(identical(other.dots, dots) || other.dots == dots)&&(identical(other.canGoBack, canGoBack) || other.canGoBack == canGoBack)&&(identical(other.problem, problem) || other.problem == problem));
}


@override
int get hashCode {
    return Object.hash(runtimeType,step,progress,position,dots,canGoBack,problem);
}



}

/// @nodoc
abstract mixin class $OnboardingShowingCopyWith<$Res> implements $OnboardingStateCopyWith<$Res> {
  factory $OnboardingShowingCopyWith(OnboardingShowing value, $Res Function(OnboardingShowing) _then) = _$OnboardingShowingCopyWithImpl;
@useResult
$Res call({
 OnboardingStep step, OnboardingProgress progress, int position, int dots, bool canGoBack, DisplayNameProblem? problem
});


$OnboardingProgressCopyWith<$Res> get progress;

}
/// @nodoc
class _$OnboardingShowingCopyWithImpl<$Res>
    implements $OnboardingShowingCopyWith<$Res> {
  _$OnboardingShowingCopyWithImpl(this._self, this._then);

  final OnboardingShowing _self;
  final $Res Function(OnboardingShowing) _then;

/// Create a copy of OnboardingState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? step = null,Object? progress = null,Object? position = null,Object? dots = null,Object? canGoBack = null,Object? problem = freezed,}) {
  return _then(OnboardingShowing(
step: null == step ? _self.step : step // ignore: cast_nullable_to_non_nullable
as OnboardingStep,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as OnboardingProgress,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int,dots: null == dots ? _self.dots : dots // ignore: cast_nullable_to_non_nullable
as int,canGoBack: null == canGoBack ? _self.canGoBack : canGoBack // ignore: cast_nullable_to_non_nullable
as bool,problem: freezed == problem ? _self.problem : problem // ignore: cast_nullable_to_non_nullable
as DisplayNameProblem?,
  ));
}

/// Create a copy of OnboardingState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnboardingProgressCopyWith<$Res> get progress {
  
  return $OnboardingProgressCopyWith<$Res>(_self.progress, (value) {
    return _then(_self.copyWith(progress: value));
  });
}
}

/// @nodoc


class OnboardingSaveFailed implements OnboardingState {
  const OnboardingSaveFailed();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is OnboardingSaveFailed);
}


@override
int get hashCode => runtimeType.hashCode;



}




/// @nodoc


class OnboardingFinished implements OnboardingState {
  const OnboardingFinished(this.next);
  

 final  OnboardingNext next;

/// Create a copy of OnboardingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnboardingFinishedCopyWith<OnboardingFinished> get copyWith => _$OnboardingFinishedCopyWithImpl<OnboardingFinished>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is OnboardingFinished&&(identical(other.next, next) || other.next == next));
}


@override
int get hashCode {
    return Object.hash(runtimeType,next);
}



}

/// @nodoc
abstract mixin class $OnboardingFinishedCopyWith<$Res> implements $OnboardingStateCopyWith<$Res> {
  factory $OnboardingFinishedCopyWith(OnboardingFinished value, $Res Function(OnboardingFinished) _then) = _$OnboardingFinishedCopyWithImpl;
@useResult
$Res call({
 OnboardingNext next
});




}
/// @nodoc
class _$OnboardingFinishedCopyWithImpl<$Res>
    implements $OnboardingFinishedCopyWith<$Res> {
  _$OnboardingFinishedCopyWithImpl(this._self, this._then);

  final OnboardingFinished _self;
  final $Res Function(OnboardingFinished) _then;

/// Create a copy of OnboardingState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? next = null,}) {
  return _then(OnboardingFinished(
null == next ? _self.next : next // ignore: cast_nullable_to_non_nullable
as OnboardingNext,
  ));
}


}

// dart format on
