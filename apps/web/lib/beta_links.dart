/// The two store links the beta page hands out, and the path it lives at.
///
/// They sit apart from the page because replacing the TestFlight placeholder
/// is a separate act from writing the copy, and because the tests assert on
/// the values rather than on the rendered markup.
library;

/// Where the unlisted beta page lives. Nothing on the site links here: it
/// reaches a tester through one invitation mail and nowhere else.
const betaPath = '/beta';

/// The public TestFlight link for the external "Beta" group (App Store
/// Connect › TestFlight › Beta › public link, enabled 2026-09-20, limit 100
/// testers). It resolves once the group holds a build that passed Beta App
/// Review; the release lane distributes every build there.
const testFlightJoinUrl = 'https://testflight.apple.com/join/SDw1xhYF';

/// The Play opt-in link for the closed testing track. Derived from the
/// package name, so it is final: it resolves as soon as the track has a
/// build and the tester's account is on the list.
const playTestingUrl =
    'https://play.google.com/apps/testing/de.emotely.emotely';

/// The German beta page, unlisted like [betaPath]: only the English beta
/// page's language switch links here.
const germanBetaPath = '/de/beta';
