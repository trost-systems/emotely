import 'package:emotely_web/beta_links.dart';
import 'package:emotely_web/pages/app_privacy.dart';
import 'package:emotely_web/pages/beta.dart';
import 'package:emotely_web/pages/confirm.dart';
import 'package:emotely_web/pages/de/app_privacy.dart';
import 'package:emotely_web/pages/de/beta.dart';
import 'package:emotely_web/pages/de/confirm.dart';
import 'package:emotely_web/pages/de/delete_account.dart';
import 'package:emotely_web/pages/de/home.dart';
import 'package:emotely_web/pages/de/imprint.dart';
import 'package:emotely_web/pages/de/privacy.dart';
import 'package:emotely_web/pages/delete_account.dart';
import 'package:emotely_web/pages/home.dart';
import 'package:emotely_web/pages/imprint.dart';
import 'package:emotely_web/pages/privacy.dart';
import 'package:emotely_web/site_locale.dart';
import 'package:emotely_web/site_shell.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

/// The site: one shell per language around its pages — English at `/…`,
/// German at `/de/…` ([SiteLocale]). Built only on the server; the
/// client-side islands are the waitlist form, the waitlist confirmation
/// and the account-deletion form.
class const App({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) => Router(
    routes: [
      ShellRoute(
        builder: (_, state, child) =>
            SiteShell(locale: .en, path: _pathOf(state), child: child),
        routes: [
          Route(
            path: '/',
            title: 'emotely — a journal that asks, listens and writes',
            builder: (_, _) => const Home(),
          ),
          Route(
            path: '/confirm',
            title: 'Confirm your address — emotely',
            builder: (_, _) => const Confirm(),
          ),
          Route(
            path: '/privacy',
            title: 'Privacy — emotely',
            builder: (_, _) => const Privacy(),
          ),
          // The URL both store listings point at. Google Play rejected the
          // 2026-09-13 update because the legacy emotely.de/app-privacy/ was
          // dead and /privacy disclaims the app in its first sentence.
          Route(
            path: '/app-privacy',
            title: 'App privacy notice — emotely',
            builder: (_, _) => const AppPrivacy(),
          ),
          Route(
            path: '/delete-account',
            title: 'Delete your account — emotely',
            builder: (_, _) => const DeleteAccount(),
          ),
          Route(
            path: '/imprint',
            title: 'Imprint — emotely',
            builder: (_, _) => const Imprint(),
          ),
          // Unlisted: the route exists so the page builds and resolves, but
          // nothing links to it and `--sitemap-exclude` keeps it out of
          // sitemap.xml. The page itself carries `noindex, nofollow`.
          Route(
            path: betaPath,
            title: 'emotely beta',
            builder: (_, _) => const Beta(),
          ),
        ],
      ),
      // Every path here is listed in `germanPaths`; a test renders each
      // entry of that table, so one without its route fails.
      ShellRoute(
        builder: (_, state, child) =>
            SiteShell(locale: .de, path: _pathOf(state), child: child),
        routes: [
          Route(
            path: '/de',
            title: 'emotely — ein Tagebuch, das fragt, zuhört und schreibt',
            builder: (_, _) => const HomeDe(),
          ),
          Route(
            path: '/de/confirm',
            title: 'Bestätige deine Adresse — emotely',
            builder: (_, _) => const ConfirmDe(),
          ),
          // The site notice: what the German waitlist form stores (#253).
          Route(
            path: '/de/privacy',
            title: 'Datenschutzerklärung — emotely',
            builder: (_, _) => const PrivacyDe(),
          ),
          // Where the app's German consent and privacy screens link (#229).
          Route(
            path: '/de/app-privacy',
            title: 'Datenschutzerklärung der App — emotely',
            builder: (_, _) => const AppPrivacyDe(),
          ),
          Route(
            path: '/de/delete-account',
            title: 'Dein Konto löschen — emotely',
            builder: (_, _) => const DeleteAccountDe(),
          ),
          Route(
            path: '/de/imprint',
            title: 'Impressum — emotely',
            builder: (_, _) => const ImprintDe(),
          ),
          // Unlisted, like /beta: `--sitemap-exclude` keeps it out of
          // sitemap.xml, and only the English beta page links here.
          Route(
            path: germanBetaPath,
            title: 'emotely-Beta',
            builder: (_, _) => const BetaDe(),
          ),
        ],
      ),
    ],
  );
}

/// The path of the route a shell frames, without its query: `/confirm`
/// for `/confirm?t=…`.
String _pathOf(RouteState state) =>
    state.fullpath ?? Uri.parse(state.location).path;
