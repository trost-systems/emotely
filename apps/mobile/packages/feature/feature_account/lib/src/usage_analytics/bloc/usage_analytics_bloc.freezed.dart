// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'usage_analytics_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UsageAnalyticsEvent {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UsageAnalyticsEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'UsageAnalyticsEvent()';
}


}

/// @nodoc
class $UsageAnalyticsEventCopyWith<$Res>  {
$UsageAnalyticsEventCopyWith(UsageAnalyticsEvent _, $Res Function(UsageAnalyticsEvent) __);
}


/// Adds pattern-matching-related methods to [UsageAnalyticsEvent].
extension UsageAnalyticsEventPatterns on UsageAnalyticsEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UsageAnalyticsStarted value)?  started,TResult Function( UsageAnalyticsAllowed value)?  allowed,TResult Function( UsageAnalyticsDenied value)?  denied,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UsageAnalyticsStarted() when started != null:
return started(_that);case UsageAnalyticsAllowed() when allowed != null:
return allowed(_that);case UsageAnalyticsDenied() when denied != null:
return denied(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UsageAnalyticsStarted value)  started,required TResult Function( UsageAnalyticsAllowed value)  allowed,required TResult Function( UsageAnalyticsDenied value)  denied,}){
final _that = this;
switch (_that) {
case UsageAnalyticsStarted():
return started(_that);case UsageAnalyticsAllowed():
return allowed(_that);case UsageAnalyticsDenied():
return denied(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UsageAnalyticsStarted value)?  started,TResult? Function( UsageAnalyticsAllowed value)?  allowed,TResult? Function( UsageAnalyticsDenied value)?  denied,}){
final _that = this;
switch (_that) {
case UsageAnalyticsStarted() when started != null:
return started(_that);case UsageAnalyticsAllowed() when allowed != null:
return allowed(_that);case UsageAnalyticsDenied() when denied != null:
return denied(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  started,TResult Function()?  allowed,TResult Function()?  denied,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UsageAnalyticsStarted() when started != null:
return started();case UsageAnalyticsAllowed() when allowed != null:
return allowed();case UsageAnalyticsDenied() when denied != null:
return denied();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  started,required TResult Function()  allowed,required TResult Function()  denied,}) {final _that = this;
switch (_that) {
case UsageAnalyticsStarted():
return started();case UsageAnalyticsAllowed():
return allowed();case UsageAnalyticsDenied():
return denied();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  started,TResult? Function()?  allowed,TResult? Function()?  denied,}) {final _that = this;
switch (_that) {
case UsageAnalyticsStarted() when started != null:
return started();case UsageAnalyticsAllowed() when allowed != null:
return allowed();case UsageAnalyticsDenied() when denied != null:
return denied();case _:
  return null;

}
}

}

/// @nodoc


class UsageAnalyticsStarted implements UsageAnalyticsEvent {
  const UsageAnalyticsStarted();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UsageAnalyticsStarted);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'UsageAnalyticsEvent.started()';
}


}




/// @nodoc


class UsageAnalyticsAllowed implements UsageAnalyticsEvent {
  const UsageAnalyticsAllowed();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UsageAnalyticsAllowed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'UsageAnalyticsEvent.allowed()';
}


}




/// @nodoc


class UsageAnalyticsDenied implements UsageAnalyticsEvent {
  const UsageAnalyticsDenied();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UsageAnalyticsDenied);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'UsageAnalyticsEvent.denied()';
}


}




// dart format on
