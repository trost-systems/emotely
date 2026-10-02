import 'package:contract/contract.dart';
import 'package:flutter/foundation.dart' show immutable;

/// Why a typed name cannot be the profile's name.
enum DisplayNameProblem() {
  /// Nothing is left once it is trimmed.
  empty,

  /// More than [maxDisplayNameLength] code points once trimmed.
  tooLong,

  /// It holds a control character (Unicode category Cc), such as a line
  /// break, which would read as a new line of the companion's prompt.
  controlCharacter,

  /// It holds a character that rearranges the text around it: a line or
  /// paragraph separator (U+2028, U+2029), a line break that is not a
  /// control character, or a bidirectional embedding, override or isolate
  /// (U+202A to U+202E, U+2066 to U+2069), which would reverse or reorder
  /// the greeting and the prompt line it sits in (#214).
  layoutCharacter,
}

/// A name the `profiles` table accepts: trimmed as Dart trims, 1 to
/// [maxDisplayNameLength] Unicode code points, no control character and no
/// layout character. The same four rules as the table's checks, so a name
/// that passes here is never refused there, and one refused there never
/// gets this far.
///
/// The only way to one is [check], so the repository cannot be handed a
/// name nobody checked. Printing it prints no name (ADR 0005).
@immutable
final class const DisplayName._(final String value) {
  /// Checks [raw] — what the user typed — and says what it makes.
  static DisplayNameCheck check(String raw) {
    final name = raw.trim();
    if (name.isEmpty) {
      return const DisplayNameRefused(DisplayNameProblem.empty);
    }
    if (name.runes.length > maxDisplayNameLength) {
      return const DisplayNameRefused(DisplayNameProblem.tooLong);
    }
    if (name.runes.any(_isControl)) {
      return const DisplayNameRefused(DisplayNameProblem.controlCharacter);
    }
    if (name.runes.any(_isLayout)) {
      return const DisplayNameRefused(DisplayNameProblem.layoutCharacter);
    }
    return DisplayNameAccepted(DisplayName._(name));
  }

  /// Unicode category Cc: C0, DEL and C1. NUL is among them here although
  /// the table's check starts at U+0001, because Postgres cannot store a
  /// NUL in text at all.
  static bool _isControl(int rune) =>
      rune <= 0x1f || (rune >= 0x7f && rune <= 0x9f);

  /// The line and paragraph separators (Zl, Zp) and the bidirectional
  /// embeddings, overrides and isolates. The other invisible format
  /// characters (Cf) stay allowed: ZWJ builds emoji, ZWNJ spells Persian and
  /// Indic names, tag characters build subdivision flags, and a
  /// left-to-right or right-to-left mark affects only its neighbors.
  static bool _isLayout(int rune) =>
      rune == 0x2028 ||
      rune == 0x2029 ||
      (rune >= 0x202a && rune <= 0x202e) ||
      (rune >= 0x2066 && rune <= 0x2069);

  @override
  bool operator ==(Object other) =>
      other is DisplayName && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// What [DisplayName.check] made of a typed name.
sealed class const DisplayNameCheck();

/// The typed name is a [name] the profile takes.
final class const DisplayNameAccepted(final DisplayName name)
    extends DisplayNameCheck;

/// The typed name cannot be the profile's name, for [problem].
final class const DisplayNameRefused(final DisplayNameProblem problem)
    extends DisplayNameCheck;
