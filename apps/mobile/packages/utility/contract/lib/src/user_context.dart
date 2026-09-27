import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_context.freezed.dart';
part 'user_context.g.dart';

/// What the companion may know about the person it talks to, sent as
/// `user_context` with every session round (#204). The agent takes the whole
/// object, so a later member — a local date, a time zone, a locale — is one
/// more optional field here and in `packages/contract`.
///
/// This is personal data on its way to the model provider, which is why the
/// journal consent names it; `toString` is left alone so a log, an
/// assertion or a `BlocObserver` never prints the name (ADR 0005).
@Freezed(toStringOverride: false)
abstract class UserContext with _$UserContext {
  /// Creates the context for one session round.
  const factory({
    /// What the user wants to be called: the name they typed, or the
    /// placeholder emotely picked for them. Omitted from the wire when
    /// there is none. At most [maxDisplayNameLength] code points
    /// (`runes.length`) after `trim()`, with no control characters, or the
    /// agent ignores the whole context.
    @JsonKey(includeIfNull: false) String? displayName,

    /// True when `displayName` is that placeholder, not a real name.
    @Default(false) bool nameIsPlaceholder,
  }) = _UserContext;

  /// Decodes the wire shape; the app only encodes, the round trip pins it.
  factory fromJson(Map<String, dynamic> json) => _$UserContextFromJson(json);
}

/// The longest display name the agent takes, after `trim()`, in Unicode code
/// points (`runes.length`, not `length`: forty emoji fit) — the same rule as
/// the `profiles` table's check. Mirrors `maxDisplayNameLength` in
/// `packages/contract`, pinned against its generated JSON Schema in the
/// app's contract test.
const maxDisplayNameLength = 40;
