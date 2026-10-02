// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_context.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserContext _$UserContextFromJson(Map<String, dynamic> json) => _UserContext(
  displayName: json['display_name'] as String?,
  nameIsPlaceholder: json['name_is_placeholder'] as bool? ?? false,
  locale: _$JsonConverterFromJson<String, Locale>(
    json['locale'],
    const LanguageTagConverter().fromJson,
  ),
);

Map<String, dynamic> _$UserContextToJson(_UserContext instance) =>
    <String, dynamic>{
      'display_name': ?instance.displayName,
      'name_is_placeholder': instance.nameIsPlaceholder,
      'locale': ?_$JsonConverterToJson<String, Locale>(
        instance.locale,
        const LanguageTagConverter().toJson,
      ),
    };

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);
