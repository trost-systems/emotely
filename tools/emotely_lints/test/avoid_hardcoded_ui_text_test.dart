// The analyzer's rule tests are reflective: the loader runs every method
// whose name starts with `test_`, so these names cannot be lowerCamelCase.
// ignore_for_file: non_constant_identifier_names
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:emotely_lints/src/avoid_hardcoded_ui_text.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidHardcodedUiTextTest);
  });
}

@reflectiveTest
class AvoidHardcodedUiTextTest() extends AnalysisRuleTest {
  // analyzer_testing's stub `flutter` package: Text, StatelessWidget,
  // TextSpan and friends, enough to resolve the types the rule looks at.
  @override
  bool get addFlutterPackageDep => true;

  @override
  void setUp() {
    rule = AvoidHardcodedUiText();
    super.setUp();
  }

  Future<void> test_literalGivenToText() async {
    const code = '''
import 'package:flutter/widgets.dart';
Widget f() => Text('Start journaling');
''';
    await assertDiagnostics(code, [
      lint(code.indexOf("'Start journaling'"), "'Start journaling'".length),
    ]);
  }

  Future<void> test_literalGivenToANullableTextParameter() async {
    const code = '''
import 'package:flutter/widgets.dart';
Widget f(String s) => Text(s, semanticsLabel: 'Close');
''';
    await assertDiagnostics(code, [
      lint(code.indexOf("'Close'"), "'Close'".length),
    ]);
  }

  Future<void> test_interpolationWithWords() async {
    const code = r'''
import 'package:flutter/widgets.dart';
Widget f(String name) => Text('Hello, $name');
''';
    await assertDiagnostics(code, [
      lint(code.indexOf(r"'Hello, $name'"), r"'Hello, $name'".length),
    ]);
  }

  Future<void> test_adjacentStrings() async {
    const code = '''
import 'package:flutter/widgets.dart';
Widget f() => Text('One sentence, '
    'and the next.');
''';
    await assertDiagnostics(code, [
      lint(code.indexOf("'One"), code.indexOf(');') - code.indexOf("'One")),
    ]);
  }

  Future<void> test_literalGivenToOurOwnWidget() async {
    const code = '''
import 'package:flutter/widgets.dart';
class Row extends StatelessWidget {
  const Row({required this.title});
  final String title;
  Widget build(BuildContext context) => Text(title);
}
Widget f() => const Row(title: 'Privacy');
''';
    await assertDiagnostics(code, [
      lint(code.indexOf("'Privacy'"), "'Privacy'".length),
    ]);
  }

  Future<void> test_textParameterOfAFlutterClassThatIsNotAWidget() async {
    const code = '''
import 'package:flutter/painting.dart';
Object f() => const TextSpan(text: 'Read the notice');
''';
    await assertDiagnostics(code, [
      lint(code.indexOf("'Read the notice'"), "'Read the notice'".length),
    ]);
  }

  Future<void> test_textParameterOfAMethodOnAWidget() async {
    const code = '''
import 'package:flutter/widgets.dart';
class Announcer extends StatelessWidget {
  static void announce({required String message}) {}
  Widget build(BuildContext context) => const Text('x');
}
void f() => Announcer.announce(message: 'Saved');
''';
    await assertDiagnostics(code, [
      lint(code.indexOf("'x'"), "'x'".length),
      lint(code.indexOf("'Saved'"), "'Saved'".length),
    ]);
  }

  Future<void> test_localizedStringIsFine() async {
    await assertNoDiagnostics('''
import 'package:flutter/widgets.dart';
class Strings { String get title => ''; }
Widget f(Strings strings) => Text(strings.title);
''');
  }

  Future<void> test_literalWithoutAnyLetter() async {
    // Punctuation, digits and emoji are not language: '·', '8 / 10', '😊'.
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
Widget f(int a, int b) => Column(children: [
  Text('·'),
  Text('$a / $b'),
  Text('😊 🌤️'),
]);
''');
  }

  Future<void> test_nonTextParameterOfAWidget() async {
    await assertNoDiagnostics('''
import 'package:flutter/widgets.dart';
class Logo extends StatelessWidget {
  const Logo({required this.asset, this.restorationId});
  final String asset;
  final String? restorationId;
  Widget build(BuildContext context) => Text(asset);
}
Widget f() => const Logo(
  asset: 'assets/google/light.png',
  restorationId: 'logo',
);
''');
  }

  Future<void> test_urlGivenToAWidget() async {
    await assertNoDiagnostics('''
import 'package:flutter/widgets.dart';
class Link extends StatelessWidget {
  const Link({required this.url});
  final String url;
  Widget build(BuildContext context) => Text(url);
}
Widget f() => const Link(url: 'https://getemotely.com/app-privacy');
''');
  }

  Future<void> test_messageOfAClassThatIsNotUi() async {
    // An exception's message is for error tracking, not for the screen.
    await assertNoDiagnostics('''
class ConfigException implements Exception {
  const ConfigException(this.message);
  final String message;
}
Never f() => throw const ConfigException('emotely answered 503.');
''');
  }

  Future<void> test_keysAreNotText() async {
    await assertNoDiagnostics('''
import 'package:flutter/widgets.dart';
const key = ValueKey('consent_page.agree');
''');
  }

  Future<void> test_constantGivenToText() async {
    // The most common way round the rule: a const beside the widget.
    const code = '''
import 'package:flutter/widgets.dart';
const consentTitle = 'Before emotely sends your writing';
Widget f() => const Text(consentTitle);
''';
    await assertDiagnostics(code, [
      lint(code.lastIndexOf('consentTitle'), 'consentTitle'.length),
    ]);
  }

  Future<void> test_staticConstantGivenToText() async {
    const code = '''
import 'package:flutter/widgets.dart';
class Copy { static const agree = 'Start journaling'; }
Widget f() => const Text(Copy.agree);
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('Copy.agree'), 'Copy.agree'.length),
    ]);
  }

  Future<void> test_constantWithoutWordsIsFine() async {
    await assertNoDiagnostics('''
import 'package:flutter/widgets.dart';
const separator = ' · ';
Widget f() => const Text(separator);
''');
  }

  Future<void> test_flutterExceptionsAreNotUi() async {
    // A platform error's message is for logs, even though it is Flutter's
    // and the parameter is called `message`.
    newFile('$packagesRootPath/flutter/lib/services.dart', '''
class PlatformException implements Exception {
  PlatformException({required String code, String? message});
}
''');
    await assertNoDiagnostics('''
import 'package:flutter/services.dart';
Never f() => throw PlatformException(
  code: 'ACTIVITY_NOT_FOUND',
  message: 'No app found to handle the URL',
);
''');
  }

  Future<void> test_testsMayUseLiterals() async {
    final path = '$testPackageRootPath/test/page_test.dart';
    newFile(path, '''
import 'package:flutter/widgets.dart';
Widget f() => Text('Start journaling');
''');
    await assertNoDiagnosticsInFile(path);
  }
}
