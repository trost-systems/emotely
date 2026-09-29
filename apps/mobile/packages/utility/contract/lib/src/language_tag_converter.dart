import 'dart:ui';

import 'package:json_annotation/json_annotation.dart';

/// A BCP 47 language tag on the wire (`de`, `de-AT`, `zh-Hant-TW`), a
/// [Locale] in Dart: [Locale.toLanguageTag], never `toString`, which writes
/// `de_AT` and is no tag at all. The agent takes a language, an optional
/// script and an optional region, which is all a [Locale] the app resolves
/// ever has; its pattern is pinned against this in the app's contract test.
class const LanguageTagConverter() implements JsonConverter<Locale, String> {
  static final _tag = RegExp(
    r'^([A-Za-z]{2,3})(?:-([A-Za-z]{4}))?(?:-([A-Za-z]{2}|\d{3}))?$',
  );

  @override
  Locale fromJson(String json) {
    final match = _tag.firstMatch(json);
    if (match == null) {
      throw FormatException('expected a BCP 47 language tag', json);
    }
    return Locale.fromSubtags(
      languageCode: match.group(1)!,
      scriptCode: match.group(2),
      countryCode: match.group(3),
    );
  }

  @override
  String toJson(Locale object) => object.toLanguageTag();
}
