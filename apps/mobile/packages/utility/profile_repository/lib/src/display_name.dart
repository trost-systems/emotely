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
}

/// A name the `profiles` table accepts: trimmed as Dart trims, 1 to
/// [maxDisplayNameLength] Unicode code points, no control character. The
/// same three rules as the table's checks, so a name that passes here is
/// never refused there, and one refused there never gets this far.
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
    return DisplayNameAccepted(DisplayName._(name));
  }

  /// Unicode category Cc: C0, DEL and C1. NUL is among them here although
  /// the table's check starts at U+0001, because Postgres cannot store a
  /// NUL in text at all.
  static bool _isControl(int rune) =>
      rune <= 0x1f || (rune >= 0x7f && rune <= 0x9f);

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
