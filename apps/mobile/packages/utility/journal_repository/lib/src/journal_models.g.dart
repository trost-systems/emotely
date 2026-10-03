// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OpenSession _$OpenSessionFromJson(Map<String, dynamic> json) => _OpenSession(
  id: json['id'] as String,
  transcript: json['transcript'] as List<dynamic>,
  signature: json['signature'] as String,
  questions: (json['questions'] as List<dynamic>)
      .map((e) => AskQuestion.fromJson(e as Map<String, dynamic>))
      .toList(),
  pending: json['pending'] == null
      ? null
      : PendingQuestion.fromJson(json['pending'] as Map<String, dynamic>),
);

Map<String, dynamic> _$OpenSessionToJson(_OpenSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'transcript': instance.transcript,
      'signature': instance.signature,
      'questions': instance.questions.map((e) => e.toJson()).toList(),
      'pending': instance.pending?.toJson(),
    };

_EntryRecord _$EntryRecordFromJson(Map<String, dynamic> json) => _EntryRecord(
  id: json['id'] as String,
  summary: json['summary'] as String,
  answers: (json['answers'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(k, Answer.fromJson(e as Map<String, dynamic>)),
  ),
  questions: (json['questions'] as List<dynamic>)
      .map((e) => AskQuestion.fromJson(e as Map<String, dynamic>))
      .toList(),
  journalDay: DateTime.parse(json['journal_day'] as String),
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$EntryRecordToJson(_EntryRecord instance) =>
    <String, dynamic>{
      'id': instance.id,
      'summary': instance.summary,
      'answers': instance.answers.map((k, e) => MapEntry(k, e.toJson())),
      'questions': instance.questions.map((e) => e.toJson()).toList(),
      'journal_day': instance.journalDay.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
    };
