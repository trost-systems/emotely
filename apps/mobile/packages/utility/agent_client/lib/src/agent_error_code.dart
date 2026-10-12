/// Why the agent refused a round: the `code` of its error response.
///
/// Mirrors `errorCodes` in `packages/contract`; the wire names are pinned
/// against the generated JSON Schema in `test/contract/contract_schema_test`.
/// The app acts on the code and words the failure itself, so no server text
/// reaches a screen and every message can be localized.
enum AgentErrorCode(final String wire) {
  /// No live sign-in on the request; a renewed token may succeed.
  unauthorized('unauthorized'),

  /// The transcript is not one the agent signed: the session cannot go on.
  invalidSignature('invalid_signature'),

  /// The session is past the message cap: it cannot go on either.
  transcriptTooLong('transcript_too_long'),

  /// The answer is over the size cap.
  answerTooLarge('answer_too_large'),

  /// The answer names a question that is not the pending one.
  answerMismatch('answer_mismatch'),

  /// The request body is not the contract's envelope.
  malformedRequest('malformed_request'),

  /// Anything but POST.
  methodNotAllowed('method_not_allowed'),

  /// The gateway refused the round; waiting is what helps.
  modelUnavailable('model_unavailable'),

  /// Revoking Sign in with Apple (#193): the code is for an Apple ID other
  /// than the one linked to this account, or the account has none.
  appleIdentityMismatch('apple_identity_mismatch'),

  /// Revoking Sign in with Apple: Apple or Supabase refused or could not be
  /// reached, so the grant is still in place.
  appleRevocationUnavailable('apple_revocation_unavailable');

  /// The code for [wire], or null for one this build does not know, so a
  /// code added on the server later degrades to a generic failure.
  static AgentErrorCode? fromWire(Object? wire) {
    for (final code in values) {
      if (code.wire == wire) {
        return code;
      }
    }
    return null;
  }
}
