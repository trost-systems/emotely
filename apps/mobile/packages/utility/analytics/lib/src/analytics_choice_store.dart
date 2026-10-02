import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// What the user answered to "May I count how you use the app?" (#204).
/// No answer at all is `null`: the question has not been asked on this
/// device, or was asked of someone who has since signed out.
enum AnalyticsChoice() {
  /// PostHog may be set up: events, error tracking and surveys.
  allowed,

  /// PostHog stays off, or is switched off again.
  denied,
}

/// A choice as the device keeps it: the answer, and whose it is (#216).
///
/// `account` is the id of the account the answer belongs to, or `null` for
/// an answer given before anyone signed in on this device — the first-launch
/// sheet comes before sign-up — which the first account to sign in adopts.
typedef StoredChoice = ({AnalyticsChoice choice, String? account});

/// The usage-analytics choice as this device keeps it.
///
/// On the device because the question comes before there is an account to
/// record it against (§ 25 TDDDG asks before anything is stored for
/// analytics, and there is nobody to attribute a server record to yet).
/// Keeping the answer is itself technically necessary: without it the app
/// would have to ask on every launch. Once someone signs in, the consent
/// record on the server holds the evidence (ADR 0014); this store only
/// decides whether PostHog runs here.
///
/// The answer is kept together with whose it is, in one value, so the two
/// can never be read apart: a session can end while the app is closed, and
/// the next launch must be able to tell the last person's answer from the
/// next person's (#216).
class const AnalyticsChoiceStore({
  required final SharedPreferencesAsync preferences,
}) {
  /// The one key this store owns.
  static const key = 'usage_analytics_choice';

  /// The value [write] keeps under [key] for [choice], belonging to
  /// [account].
  static String valueOf(AnalyticsChoice choice, {required String? account}) =>
      jsonEncode({'choice': choice.name, 'account': account});

  /// The stored choice and whose it is, or `null` when none is stored.
  ///
  /// A value this build does not recognize counts as none: asking again is
  /// the only answer that cannot count someone who never agreed. That
  /// includes what the #204 builds wrote, the choice alone: it may be the
  /// answer of someone whose session ended while the app was closed, and
  /// nothing on the device can say whether it is.
  Future<StoredChoice?> read() async {
    final stored = await preferences.getString(key);
    if (stored == null) {
      return null;
    }
    final Object? json;
    try {
      json = jsonDecode(stored);
    } on FormatException {
      return null;
    }
    if (json case {
      'choice': final String name,
      'account': final String? account,
    }) {
      for (final choice in AnalyticsChoice.values) {
        if (choice.name == name) {
          return (choice: choice, account: account);
        }
      }
    }
    return null;
  }

  /// Keeps [choice], belonging to [account], for the next launch.
  Future<void> write(AnalyticsChoice choice, {required String? account}) =>
      preferences.setString(key, valueOf(choice, account: account));

  /// Forgets the choice, so the question is asked again.
  Future<void> clear() => preferences.remove(key);
}
