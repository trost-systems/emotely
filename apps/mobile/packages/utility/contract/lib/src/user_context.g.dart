// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_context.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserContext _$UserContextFromJson(Map<String, dynamic> json) => _UserContext(
  displayName: json['display_name'] as String?,
  nameIsPlaceholder: json['name_is_placeholder'] as bool? ?? false,
);

Map<String, dynamic> _$UserContextToJson(_UserContext instance) =>
    <String, dynamic>{
      'display_name': ?instance.displayName,
      'name_is_placeholder': instance.nameIsPlaceholder,
    };
