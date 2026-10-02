// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'answer.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
Answer _$AnswerFromJson(
  Map<String, dynamic> json
) {
        switch (json['answer_type']) {
                  case 'color':
          return ColorAnswer.fromJson(
            json
          );
                case 'emoji':
          return EmojiAnswer.fromJson(
            json
          );
                case 'longtext':
          return LongtextAnswer.fromJson(
            json
          );
                case 'rating':
          return RatingAnswer.fromJson(
            json
          );
                case 'text_list':
          return TextListAnswer.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'answer_type',
  'Answer',
  'Invalid union type "${json['answer_type']}"!'
);
        }
      
}

/// @nodoc
mixin _$Answer {

@HexColorConverter() Object get value;

  /// Serializes this Answer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Answer;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Answer&&const DeepCollectionEquality().equals(other.value, _this.value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Answer;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.value));
}

@override
String toString() {
  final _this = this as Answer;
  return 'Answer(value: ${_this.value})';
}


}

/// @nodoc
class $AnswerCopyWith<$Res>  {
$AnswerCopyWith(Answer _, $Res Function(Answer) __);
}


/// Adds pattern-matching-related methods to [Answer].
extension AnswerPatterns on Answer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ColorAnswer value)?  color,TResult Function( EmojiAnswer value)?  emoji,TResult Function( LongtextAnswer value)?  longtext,TResult Function( RatingAnswer value)?  rating,TResult Function( TextListAnswer value)?  textList,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ColorAnswer() when color != null:
return color(_that);case EmojiAnswer() when emoji != null:
return emoji(_that);case LongtextAnswer() when longtext != null:
return longtext(_that);case RatingAnswer() when rating != null:
return rating(_that);case TextListAnswer() when textList != null:
return textList(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ColorAnswer value)  color,required TResult Function( EmojiAnswer value)  emoji,required TResult Function( LongtextAnswer value)  longtext,required TResult Function( RatingAnswer value)  rating,required TResult Function( TextListAnswer value)  textList,}){
final _that = this;
switch (_that) {
case ColorAnswer():
return color(_that);case EmojiAnswer():
return emoji(_that);case LongtextAnswer():
return longtext(_that);case RatingAnswer():
return rating(_that);case TextListAnswer():
return textList(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ColorAnswer value)?  color,TResult? Function( EmojiAnswer value)?  emoji,TResult? Function( LongtextAnswer value)?  longtext,TResult? Function( RatingAnswer value)?  rating,TResult? Function( TextListAnswer value)?  textList,}){
final _that = this;
switch (_that) {
case ColorAnswer() when color != null:
return color(_that);case EmojiAnswer() when emoji != null:
return emoji(_that);case LongtextAnswer() when longtext != null:
return longtext(_that);case RatingAnswer() when rating != null:
return rating(_that);case TextListAnswer() when textList != null:
return textList(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function(@HexColorConverter()  List<Color> value)?  color,TResult Function( List<String> value)?  emoji,TResult Function( String value)?  longtext,TResult Function( int value)?  rating,TResult Function( List<String> value)?  textList,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ColorAnswer() when color != null:
return color(_that.value);case EmojiAnswer() when emoji != null:
return emoji(_that.value);case LongtextAnswer() when longtext != null:
return longtext(_that.value);case RatingAnswer() when rating != null:
return rating(_that.value);case TextListAnswer() when textList != null:
return textList(_that.value);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function(@HexColorConverter()  List<Color> value)  color,required TResult Function( List<String> value)  emoji,required TResult Function( String value)  longtext,required TResult Function( int value)  rating,required TResult Function( List<String> value)  textList,}) {final _that = this;
switch (_that) {
case ColorAnswer():
return color(_that.value);case EmojiAnswer():
return emoji(_that.value);case LongtextAnswer():
return longtext(_that.value);case RatingAnswer():
return rating(_that.value);case TextListAnswer():
return textList(_that.value);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function(@HexColorConverter()  List<Color> value)?  color,TResult? Function( List<String> value)?  emoji,TResult? Function( String value)?  longtext,TResult? Function( int value)?  rating,TResult? Function( List<String> value)?  textList,}) {final _that = this;
switch (_that) {
case ColorAnswer() when color != null:
return color(_that.value);case EmojiAnswer() when emoji != null:
return emoji(_that.value);case LongtextAnswer() when longtext != null:
return longtext(_that.value);case RatingAnswer() when rating != null:
return rating(_that.value);case TextListAnswer() when textList != null:
return textList(_that.value);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class ColorAnswer implements Answer {
  const ColorAnswer(@HexColorConverter()  List<Color> value, { String? $type}): _value = value,$type = $type ?? 'color';
  factory ColorAnswer.fromJson(Map<String, dynamic> json) => _$ColorAnswerFromJson(json);

 final  List<Color> _value;
@override@HexColorConverter() List<Color> get value {
  if (_value is EqualUnmodifiableListView) return _value;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_value);
}


@JsonKey(name: 'answer_type')
final String $type;


/// Create a copy of Answer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ColorAnswerCopyWith<ColorAnswer> get copyWith => _$ColorAnswerCopyWithImpl<ColorAnswer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ColorAnswerToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ColorAnswer&&const DeepCollectionEquality().equals(other.value, _value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_value));
}

@override
String toString() {
    return 'Answer.color(value: $value)';
}


}

/// @nodoc
abstract mixin class $ColorAnswerCopyWith<$Res> implements $AnswerCopyWith<$Res> {
  factory $ColorAnswerCopyWith(ColorAnswer value, $Res Function(ColorAnswer) _then) = _$ColorAnswerCopyWithImpl;
@useResult
$Res call({
@HexColorConverter() List<Color> value
});




}
/// @nodoc
class _$ColorAnswerCopyWithImpl<$Res>
    implements $ColorAnswerCopyWith<$Res> {
  _$ColorAnswerCopyWithImpl(this._self, this._then);

  final ColorAnswer _self;
  final $Res Function(ColorAnswer) _then;

/// Create a copy of Answer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? value = null,}) {
  return _then(ColorAnswer(
null == value ? _self._value : value // ignore: cast_nullable_to_non_nullable
as List<Color>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class EmojiAnswer implements Answer {
  const EmojiAnswer( List<String> value, { String? $type}): _value = value,$type = $type ?? 'emoji';
  factory EmojiAnswer.fromJson(Map<String, dynamic> json) => _$EmojiAnswerFromJson(json);

 final  List<String> _value;
@override List<String> get value {
  if (_value is EqualUnmodifiableListView) return _value;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_value);
}


@JsonKey(name: 'answer_type')
final String $type;


/// Create a copy of Answer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EmojiAnswerCopyWith<EmojiAnswer> get copyWith => _$EmojiAnswerCopyWithImpl<EmojiAnswer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EmojiAnswerToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is EmojiAnswer&&const DeepCollectionEquality().equals(other.value, _value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_value));
}

@override
String toString() {
    return 'Answer.emoji(value: $value)';
}


}

/// @nodoc
abstract mixin class $EmojiAnswerCopyWith<$Res> implements $AnswerCopyWith<$Res> {
  factory $EmojiAnswerCopyWith(EmojiAnswer value, $Res Function(EmojiAnswer) _then) = _$EmojiAnswerCopyWithImpl;
@useResult
$Res call({
 List<String> value
});




}
/// @nodoc
class _$EmojiAnswerCopyWithImpl<$Res>
    implements $EmojiAnswerCopyWith<$Res> {
  _$EmojiAnswerCopyWithImpl(this._self, this._then);

  final EmojiAnswer _self;
  final $Res Function(EmojiAnswer) _then;

/// Create a copy of Answer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? value = null,}) {
  return _then(EmojiAnswer(
null == value ? _self._value : value // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class LongtextAnswer implements Answer {
  const LongtextAnswer(this.value, { String? $type}): $type = $type ?? 'longtext';
  factory LongtextAnswer.fromJson(Map<String, dynamic> json) => _$LongtextAnswerFromJson(json);

@override final  String value;

@JsonKey(name: 'answer_type')
final String $type;


/// Create a copy of Answer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LongtextAnswerCopyWith<LongtextAnswer> get copyWith => _$LongtextAnswerCopyWithImpl<LongtextAnswer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LongtextAnswerToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LongtextAnswer&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,value);
}

@override
String toString() {
    return 'Answer.longtext(value: $value)';
}


}

/// @nodoc
abstract mixin class $LongtextAnswerCopyWith<$Res> implements $AnswerCopyWith<$Res> {
  factory $LongtextAnswerCopyWith(LongtextAnswer value, $Res Function(LongtextAnswer) _then) = _$LongtextAnswerCopyWithImpl;
@useResult
$Res call({
 String value
});




}
/// @nodoc
class _$LongtextAnswerCopyWithImpl<$Res>
    implements $LongtextAnswerCopyWith<$Res> {
  _$LongtextAnswerCopyWithImpl(this._self, this._then);

  final LongtextAnswer _self;
  final $Res Function(LongtextAnswer) _then;

/// Create a copy of Answer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? value = null,}) {
  return _then(LongtextAnswer(
null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class RatingAnswer implements Answer {
  const RatingAnswer(this.value, { String? $type}): $type = $type ?? 'rating';
  factory RatingAnswer.fromJson(Map<String, dynamic> json) => _$RatingAnswerFromJson(json);

@override final  int value;

@JsonKey(name: 'answer_type')
final String $type;


/// Create a copy of Answer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RatingAnswerCopyWith<RatingAnswer> get copyWith => _$RatingAnswerCopyWithImpl<RatingAnswer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RatingAnswerToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is RatingAnswer&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,value);
}

@override
String toString() {
    return 'Answer.rating(value: $value)';
}


}

/// @nodoc
abstract mixin class $RatingAnswerCopyWith<$Res> implements $AnswerCopyWith<$Res> {
  factory $RatingAnswerCopyWith(RatingAnswer value, $Res Function(RatingAnswer) _then) = _$RatingAnswerCopyWithImpl;
@useResult
$Res call({
 int value
});




}
/// @nodoc
class _$RatingAnswerCopyWithImpl<$Res>
    implements $RatingAnswerCopyWith<$Res> {
  _$RatingAnswerCopyWithImpl(this._self, this._then);

  final RatingAnswer _self;
  final $Res Function(RatingAnswer) _then;

/// Create a copy of Answer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? value = null,}) {
  return _then(RatingAnswer(
null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
@JsonSerializable()

class TextListAnswer implements Answer {
  const TextListAnswer( List<String> value, { String? $type}): _value = value,$type = $type ?? 'text_list';
  factory TextListAnswer.fromJson(Map<String, dynamic> json) => _$TextListAnswerFromJson(json);

 final  List<String> _value;
@override List<String> get value {
  if (_value is EqualUnmodifiableListView) return _value;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_value);
}


@JsonKey(name: 'answer_type')
final String $type;


/// Create a copy of Answer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TextListAnswerCopyWith<TextListAnswer> get copyWith => _$TextListAnswerCopyWithImpl<TextListAnswer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TextListAnswerToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TextListAnswer&&const DeepCollectionEquality().equals(other.value, _value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_value));
}

@override
String toString() {
    return 'Answer.textList(value: $value)';
}


}

/// @nodoc
abstract mixin class $TextListAnswerCopyWith<$Res> implements $AnswerCopyWith<$Res> {
  factory $TextListAnswerCopyWith(TextListAnswer value, $Res Function(TextListAnswer) _then) = _$TextListAnswerCopyWithImpl;
@useResult
$Res call({
 List<String> value
});




}
/// @nodoc
class _$TextListAnswerCopyWithImpl<$Res>
    implements $TextListAnswerCopyWith<$Res> {
  _$TextListAnswerCopyWithImpl(this._self, this._then);

  final TextListAnswer _self;
  final $Res Function(TextListAnswer) _then;

/// Create a copy of Answer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? value = null,}) {
  return _then(TextListAnswer(
null == value ? _self._value : value // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
