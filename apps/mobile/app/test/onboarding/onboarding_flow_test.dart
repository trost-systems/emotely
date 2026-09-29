import 'dart:convert';

import 'package:emotely/app/shell.dart';
import 'package:feature_account/feature_account.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_journal/feature_journal.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/helpers.dart';

/// Onboarding through the whole app (#204, ADR 0019): the redirect, the
/// steps, sign-up, the name moving to the account, the first session, and
/// sign-out back to Welcome.
void main() {
  Finder key(Key key) => find.byKey(key);

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<AnalyticsSpy> launch(
    WidgetTester tester,
    SupabaseStub supabase, {
    Map<String, Object?>? kept,
  }) async {
    final analytics = AnalyticsSpy();
    if (kept != null) {
      await analytics.preferences.setString(
        OnboardingStore.key,
        jsonEncode(kept),
      );
    }
    final app = appUnderTest(
      agent: AgentStub(),
      supabase: supabase,
      analytics: analytics,
    );
    // `main` awaits the restore before the first frame.
    await GetIt.I<OnboardingStore>().restore();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    return analytics;
  }

  /// Welcome to the greeting, typing [name] or skipping it.
  Future<void> walkTo(WidgetTester tester, {String? name}) async {
    await tap(tester, key(WelcomeStepView.getStartedKey));
    await tap(tester, key(ValueStepView.continueKey));
    if (name == null) {
      await tap(tester, key(NameStepView.skipKey));
    } else {
      await tester.enterText(key(NameStepView.fieldKey), name);
      await tester.pumpAndSettle();
      await tap(tester, key(NameStepView.continueKey));
    }
  }

  Future<void> signUpWithCode(WidgetTester tester) async {
    await tester.enterText(key(SignInPage.emailKey), SupabaseStub.email);
    await tester.pump();
    await tap(tester, key(SignInPage.sendCodeKey));
    await tester.enterText(key(SignInPage.codeKey), '123456');
    await tester.pump();
    await tap(tester, key(SignInPage.signInKey));
  }

  String heading(WidgetTester tester) =>
      tester.widget<Text>(key(SignInPage.headingKey)).data!;

  /// The sign-in screen's strings, in the locale the app shows it in.
  AuthLocalizations signInStrings(WidgetTester tester) =>
      AuthLocalizations.of(tester.element(find.byType(SignInPage)));

  group('a first launch', () {
    testWidgets('walks onboarding, signs up as "Almost there, {name}", '
        'saves the name and goes straight to the first session', (
      tester,
    ) async {
      final supabase = SupabaseStub()
        ..script(otp: [codeSent()], verify: [sessionGranted()])
        // A new account: no name yet, and no consent yet.
        ..always(profileRead, rows(const []))
        ..always(consentRead, consentStands(granted: false));
      final analytics = await launch(tester, supabase);

      expect(find.byType(WelcomeStepView), findsOneWidget);

      await walkTo(tester, name: 'Peter');

      expect(find.text('Nice to meet you, Peter.'), findsOneWidget);

      await tap(tester, key(HelloStepView.startKey));

      expect(
        heading(tester),
        signInStrings(tester).signUpTitleWithName('Peter'),
      );

      await signUpWithCode(tester);

      expect(supabase.bodies('/auth/v1/otp').single['create_user'], isTrue);
      expect(supabase.bodies(profilesPath), [
        {'display_name': 'Peter', 'name_is_placeholder': false},
      ]);
      // Straight on to the first session: the journal's own way in, which
      // asks for consent first.
      expect(find.byType(ConsentPage), findsOneWidget);
      expect(GetIt.I<OnboardingStore>().progress, const OnboardingProgress());
      expect(
        analytics.events.where(
          (captured) => captured['event'] == 'onboarding_completed',
        ),
        [
          event('onboarding_completed', {
            'flow_version': onboardingFlowVersion,
            'variant': 'control',
            'next': 'session',
            'name_source': 'typed',
          }),
        ],
      );
    });

    testWidgets('saves a placeholder, flagged, when the name was skipped', (
      tester,
    ) async {
      final supabase = SupabaseStub()
        ..script(otp: [codeSent()], verify: [sessionGranted()])
        ..always(profileRead, rows(const []))
        ..always(consentRead, consentStands(granted: false));
      await launch(tester, supabase);

      await walkTo(tester);
      final placeholder = GetIt.I<OnboardingStore>().progress.placeholder!;
      await tap(tester, key(SkippedStepView.startKey));

      expect(
        heading(tester),
        signInStrings(tester).signUpTitleWithName(placeholder),
      );

      await signUpWithCode(tester);

      expect(supabase.bodies(profilesPath), [
        {'display_name': placeholder, 'name_is_placeholder': true},
      ]);
    });

    testWidgets('goes back from sign-up to the greeting', (tester) async {
      await launch(tester, SupabaseStub());
      await walkTo(tester, name: 'Peter');
      await tap(tester, key(HelloStepView.startKey));

      await tap(tester, key(SignInPage.backKey));

      expect(find.byType(HelloStepView), findsOneWidget);
      expect(GetIt.I<OnboardingStore>().readyForAccount, isFalse);
    });

    testWidgets('resumes at the step reached after a restart', (tester) async {
      await launch(
        tester,
        SupabaseStub(),
        kept: {
          'flow_version': onboardingFlowVersion,
          'completed': ['welcome', 'value'],
          'draft': 'Pe',
          'placeholder': null,
          'started': true,
        },
      );

      expect(find.byType(NameStepView), findsOneWidget);
      expect(find.text('Pe'), findsOneWidget);
    });

    testWidgets('resumes on sign-up once onboarding was done', (tester) async {
      await launch(
        tester,
        SupabaseStub(),
        kept: {
          'flow_version': onboardingFlowVersion,
          'completed': ['welcome', 'value', 'name', 'hello'],
          'draft': 'Peter',
          'placeholder': null,
          'started': true,
        },
      );

      expect(
        heading(tester),
        signInStrings(tester).signUpTitleWithName('Peter'),
      );
    });
  });

  group('"I have an account"', () {
    testWidgets('welcomes back, and tells an unknown address to get '
        'started', (tester) async {
      final supabase = SupabaseStub()
        ..script(
          otp: [
            authRefused(
              statusCode: 422,
              errorCode: 'otp_disabled',
              message: 'Signups not allowed for otp',
            ),
          ],
        );
      await launch(tester, supabase);

      await tap(tester, key(WelcomeStepView.haveAccountKey));

      expect(heading(tester), signInStrings(tester).signInTitle);

      await tester.enterText(key(SignInPage.emailKey), 'new@example.com');
      await tester.pump();
      await tap(tester, key(SignInPage.sendCodeKey));

      expect(supabase.bodies('/auth/v1/otp').single['create_user'], isFalse);
      expect(find.text(signInStrings(tester).noAccountMessage), findsOneWidget);

      await tap(tester, key(SignInPage.backKey));

      expect(find.byType(WelcomeStepView), findsOneWidget);
    });

    testWidgets('asks an account without a name for one, once, then shows '
        'the journal', (tester) async {
      final supabase = SupabaseStub()
        ..script(otp: [codeSent()], verify: [sessionGranted()])
        ..rest(profileRead, [rows(const [])])
        ..always(profileRead, rows([profileRow(displayName: 'Peter')]));
      await launch(tester, supabase);

      await signInThroughTheScreen(tester);

      expect(find.byType(NameStepView), findsOneWidget);

      await tester.enterText(key(NameStepView.fieldKey), 'Peter');
      await tester.pumpAndSettle();
      await tap(tester, key(NameStepView.continueKey));

      expect(find.byType(JournalPage), findsOneWidget);
      expect(find.textContaining(', Peter'), findsOneWidget);
    });

    testWidgets('goes straight to the journal for an account with a name', (
      tester,
    ) async {
      final supabase = SupabaseStub()
        ..script(otp: [codeSent()], verify: [sessionGranted()]);
      await launch(tester, supabase);

      await signInThroughTheScreen(tester);

      expect(find.byType(JournalPage), findsOneWidget);
      expect(supabase.to(profileSave), isEmpty);
    });
  });

  testWidgets('saves a name the device still holds when the app opens '
      'signed in', (tester) async {
    final supabase = SupabaseStub()
      ..always(profileRead, rows(const []))
      ..always(consentRead, consentStands(granted: false));
    await supabase.signedIn();
    await launch(
      tester,
      supabase,
      kept: {
        'flow_version': onboardingFlowVersion,
        'completed': ['welcome', 'value', 'name', 'hello'],
        'draft': 'Peter',
        'placeholder': null,
        'started': true,
      },
    );

    expect(supabase.bodies(profilesPath), [
      {'display_name': 'Peter', 'name_is_placeholder': false},
    ]);
  });

  testWidgets('signing out starts the next person at Welcome, with nothing '
      'of the last one kept', (tester) async {
    final supabase = SupabaseStub()..script(logout: [signedOut()]);
    await supabase.signedIn();
    await launch(tester, supabase);
    // Something typed after sign-in, as the name step keeps it.
    await GetIt.I<OnboardingStore>().save(
      const OnboardingProgress(draft: 'Pe'),
    );

    await tap(tester, key(AppShell.moreTabKey));
    await tap(tester, key(MoreView.profileKey));
    await tap(tester, key(ProfileView.signOutKey));

    expect(find.byType(WelcomeStepView), findsOneWidget);
    final progress = GetIt.I<OnboardingStore>().progress;
    expect(progress.draft, isEmpty);
    expect(progress.completed, isEmpty);
  });

  testWidgets('signing out keeps the way in last used, tagged for the next '
      'sign-in', (tester) async {
    final semantics = tester.ensureSemantics();
    final supabase = SupabaseStub()
      ..script(
        otp: [codeSent()],
        verify: [sessionGranted()],
        logout: [signedOut()],
      );
    await launch(tester, supabase);
    await signInThroughTheScreen(tester);

    await tap(tester, key(AppShell.moreTabKey));
    await tap(tester, key(MoreView.profileKey));
    await tap(tester, key(ProfileView.signOutKey));
    // The analytics choice is the next person's to make.
    await tap(tester, key(UsageAnalyticsSheet.denyKey));
    await tap(tester, key(WelcomeStepView.haveAccountKey));

    final strings = signInStrings(tester);
    expect(find.text(strings.lastUsedTag), findsOneWidget);
    expect(
      find.bySemanticsLabel(strings.lastUsedButton(strings.sendCodeButton)),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
