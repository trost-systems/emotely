import 'package:feature_auth/src/gen/assets.gen.dart';
import 'package:feature_auth/src/view/provider_buttons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInExceptionCode;
import 'package:material_ui/material_ui.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart'
    show AppleLogoPainter;
import 'package:testing/testing.dart';

import '../sign_in_robot.dart';

/// Apple's button is offered on iOS alone.
final iOS = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  group(ProviderButton, () {
    SignInRobot robotFor(
      WidgetTester tester, {
      ThemeMode themeMode = ThemeMode.light,
    }) => SignInRobot(
      tester,
      supabase: SupabaseStub(),
      agent: AgentStub(),
      themeMode: themeMode,
    );

    Finder within(Finder button, Finder matching) =>
        find.descendant(of: button, matching: matching);

    Finder googleG(Finder button) => within(
      button,
      find.byWidgetPredicate(
        // Google's "G", cropped pixel for pixel from its branding assets.
        (widget) =>
            widget is Image && widget.image == Assets.google.g.provider(),
      ),
    );

    Finder appleLogo(Finder button) => within(
      button,
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is AppleLogoPainter,
      ),
    );

    /// The label's style as painted: the button's text style with its
    /// color.
    TextStyle labelStyle(WidgetTester tester, Finder button) => tester
        .widget<RichText>(within(button, find.byType(RichText)))
        .text
        .style!;

    testWidgets('labels each button with its provider’s own words', (
      tester,
    ) async {
      final robot = robotFor(tester);
      await robot.launch();

      final strings = robot.strings;
      expect(
        within(robot.appleButton, find.text(strings.appleButton)),
        findsOneWidget,
      );
      expect(
        within(robot.googleButton, find.text(strings.googleButton)),
        findsOneWidget,
      );
    }, variant: iOS);

    testWidgets('leads with the provider’s logo, and only its own', (
      tester,
    ) async {
      final robot = robotFor(tester);
      await robot.launch();

      final strings = robot.strings;
      final g = googleG(robot.googleButton);
      expect(g, findsOneWidget);
      // Google's size for the "G" on its buttons, never scaled.
      expect(tester.getSize(g), const Size.square(20));
      expect(appleLogo(robot.googleButton), findsNothing);
      expect(
        tester.getCenter(g).dx,
        lessThan(tester.getTopLeft(find.text(strings.googleButton)).dx),
      );

      final apple = appleLogo(robot.appleButton);
      expect(apple, findsOneWidget);
      expect(googleG(robot.appleButton), findsNothing);
      expect(
        tester.getCenter(apple).dx,
        lessThan(tester.getTopLeft(find.text(strings.appleButton)).dx),
      );
      // Logo and title the same black: Apple allows no other colors.
      final painter = tester.widget<CustomPaint>(apple).painter!;
      expect((painter as AppleLogoPainter).color, const Color(0xFF000000));
    }, variant: iOS);

    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('is white with Google’s gray outline on a ${themeMode.name} '
          'theme', (tester) async {
        final robot = robotFor(tester, themeMode: themeMode);
        await robot.launch();

        for (final button in [robot.appleButton, robot.googleButton]) {
          final surface = tester.widget<Material>(
            within(button, find.byType(Material)).first,
          );
          expect(surface.color, const Color(0xFFFFFFFF));
          expect(
            surface.shape,
            const StadiumBorder(side: BorderSide(color: Color(0xFF747775))),
          );
        }
        // Each provider's own ink for the title.
        expect(
          labelStyle(tester, robot.appleButton).color,
          const Color(0xFF000000),
        );
        expect(
          labelStyle(tester, robot.googleButton).color,
          const Color(0xFF1F1F1F),
        );
      }, variant: iOS);
    }

    testWidgets('sets the title in the app’s font, at Apple’s proportion to '
        'the height', (tester) async {
      final robot = robotFor(tester);
      await robot.launch();

      final font = Theme.of(tester.element(robot.googleButton))
          .textTheme
          .labelLarge!
          .fontFamily;
      for (final button in [robot.appleButton, robot.googleButton]) {
        final style = labelStyle(tester, button);
        expect(style.fontFamily, font);
        // Apple: the title's size is 43% of the button's height.
        expect(
          style.fontSize,
          closeTo(tester.getSize(button).height * 0.43, 0.01),
        );
      }
    }, variant: iOS);

    testWidgets('makes both buttons the same size: full width, at least '
        '44 tall', (tester) async {
      final robot = robotFor(tester);
      await robot.launch();

      final google = tester.getSize(robot.googleButton);
      expect(tester.getSize(robot.appleButton), google);
      expect(google.height, greaterThanOrEqualTo(44));
      expect(google.width, tester.getSize(robot.emailField).width);
    }, variant: iOS);

    testWidgets('turns both off while a sign-in is in flight', (tester) async {
      GoogleSignInFake.setup().script([
        () => Future.delayed(
          const Duration(seconds: 1),
          googleFailed(GoogleSignInExceptionCode.canceled),
        ),
      ]);
      final robot = robotFor(tester);
      await robot.launch();

      expect(robot.canTapApple, isTrue);
      expect(robot.canTapGoogle, isTrue);

      await robot.tapGoogle();

      expect(robot.canTapApple, isFalse);
      expect(robot.canTapGoogle, isFalse);

      await robot.settle();

      expect(robot.canTapApple, isTrue);
      expect(robot.canTapGoogle, isTrue);
    }, variant: iOS);
  });
}
