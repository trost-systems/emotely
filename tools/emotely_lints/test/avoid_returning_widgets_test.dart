// The analyzer's rule tests are reflective: the loader runs every method
// whose name starts with `test_`, so these names cannot be lowerCamelCase.
// ignore_for_file: non_constant_identifier_names
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:emotely_lints/src/avoid_returning_widgets.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidReturningWidgetsTest);
  });
}

@reflectiveTest
class AvoidReturningWidgetsTest() extends AnalysisRuleTest {
  // analyzer_testing's stub `flutter` package: Widget, StatelessWidget,
  // State, Text, Builder and friends.
  @override
  bool get addFlutterPackageDep => true;

  @override
  void setUp() {
    rule = AvoidReturningWidgets();
    super.setUp();
  }

  Future<void> test_topLevelFunction() async {
    const code = '''
import 'package:flutter/widgets.dart';
Widget header() => const Text('');
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('header'), 'header'.length),
    ]);
  }

  Future<void> test_privateHelperMethodOfAWidget() async {
    const code = '''
import 'package:flutter/widgets.dart';
class Page extends StatelessWidget {
  Widget _row(String label) => Text(label);
  @override
  Widget build(BuildContext context) => _row('');
}
''';
    await assertDiagnostics(code, [lint(code.indexOf('_row'), '_row'.length)]);
  }

  Future<void> test_helperMethodOfAState() async {
    const code = '''
import 'package:flutter/widgets.dart';
class Page extends StatefulWidget {
  @override
  State<Page> createState() => _PageState();
}
class _PageState extends State<Page> {
  Widget _body() => const SizedBox();
  @override
  Widget build(BuildContext context) => _body();
}
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('_body'), '_body'.length),
    ]);
  }

  Future<void> test_getterReturningAWidgetSubtype() async {
    const code = '''
import 'package:flutter/widgets.dart';
class Labels {
  Text get title => const Text('');
}
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('title'), 'title'.length),
    ]);
  }

  Future<void> test_nullableWidget() async {
    const code = '''
import 'package:flutter/widgets.dart';
Widget? badge({required bool shown}) => shown ? const SizedBox() : null;
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('badge'), 'badge'.length),
    ]);
  }

  Future<void> test_staticMethod() async {
    const code = '''
import 'package:flutter/widgets.dart';
class Screens {
  static Widget empty() => const SizedBox();
}
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('empty'), 'empty'.length),
    ]);
  }

  Future<void> test_extensionMethod() async {
    const code = '''
import 'package:flutter/widgets.dart';
extension Padded on Widget {
  Widget padded() => Padding(padding: EdgeInsets.zero, child: this);
}
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('padded'), 'padded'.length),
    ]);
  }

  Future<void> test_localFunction() async {
    const code = '''
import 'package:flutter/widgets.dart';
class Page extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget line(String text) => Text(text);
    return Column(children: [line(''), line('')]);
  }
}
''';
    await assertDiagnostics(code, [lint(code.indexOf('line'), 'line'.length)]);
  }

  Future<void> test_localFunctionWithAnInferredReturnType() async {
    const code = '''
import 'package:flutter/widgets.dart';
class Page extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    line() => const Text('');
    return line();
  }
}
''';
    await assertDiagnostics(code, [lint(code.indexOf('line'), 'line'.length)]);
  }

  Future<void> test_ourOwnAbstractMemberIsReported() async {
    // The decision to have callers return widgets is made here, once; the
    // overrides that follow it are not reported again.
    const code = '''
import 'package:flutter/widgets.dart';
abstract class Step {
  Widget view();
}
class Welcome extends Step {
  @override
  Widget view() => const SizedBox();
}
class Hello implements Step {
  @override
  Widget view() => const SizedBox();
}
''';
    await assertDiagnostics(code, [lint(code.indexOf('view'), 'view'.length)]);
  }

  Future<void> test_buildOverridesAreFine() async {
    await assertNoDiagnostics('''
import 'package:flutter/widgets.dart';
class Page extends StatefulWidget {
  @override
  State<Page> createState() => _PageState();
}
class _PageState extends State<Page> {
  @override
  Widget build(BuildContext context) => const SizedBox();
}
class Label extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Text('');
}
''');
  }

  Future<void> test_otherFrameworkOverridesAreFine() async {
    // Any method a supertype declares is the framework's (or a package's)
    // to call; its signature is not ours to change. A library of the stub
    // flutter package stands in for go_router's.
    newFile('$packagesRootPath/flutter/lib/router.dart', '''
import 'package:flutter/widgets.dart';
abstract class Route {
  Widget buildPage(BuildContext context);
}
''');
    await assertNoDiagnostics('''
import 'package:flutter/widgets.dart';
import 'package:flutter/router.dart';
class Home extends Route {
  @override
  Widget buildPage(BuildContext context) => const SizedBox();
}
''');
  }

  Future<void> test_closuresGivenAsBuildersAreFine() async {
    // A builder callback is the framework's own pattern: the builder widget
    // calls it from an element of its own, so it rebuilds on its own.
    await assertNoDiagnostics('''
import 'package:flutter/widgets.dart';
class Page extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Builder(builder: (context) => const SizedBox());
}
''');
  }

  Future<void> test_functionsReturningOtherTypesAreFine() async {
    await assertNoDiagnostics('''
import 'package:flutter/widgets.dart';
String title() => '';
List<Widget> children() => const [];
Future<void> load() async {}
class Page extends StatelessWidget {
  Key get rowKey => const ValueKey('row');
  @override
  Widget build(BuildContext context) => const SizedBox();
}
''');
  }

  Future<void> test_aClassNamedWidgetThatIsNotFlutters() async {
    await assertNoDiagnostics('''
class Widget {}
Widget make() => Widget();
''');
  }

  Future<void> test_testSupportPackageMayReturnWidgets() async {
    // A package that depends on flutter_test outside dev_dependencies can
    // never ship in the app: its lib/ is test support, like `testing`'s
    // pump helpers.
    newFile('$testPackageRootPath/pubspec.yaml', '''
name: test
dependencies:
  flutter_test:
    sdk: flutter
''');
    await assertNoDiagnostics('''
import 'package:flutter/widgets.dart';
Widget appWrapper(Widget child) => child;
''');
  }

  Future<void> test_aPackageDependingOnTestIsTestSupportToo() async {
    newFile('$testPackageRootPath/pubspec.yaml', '''
name: test
dependencies:
  test: any
''');
    await assertNoDiagnostics('''
import 'package:flutter/widgets.dart';
Widget appWrapper(Widget child) => child;
''');
  }

  Future<void> test_testDependenciesUnderDevDependenciesStillShip() async {
    // Every production package has flutter_test as a dev dependency.
    newFile('$testPackageRootPath/pubspec.yaml', '''
name: test
dependencies:
  meta: any
dev_dependencies:
  flutter_test:
    sdk: flutter
''');
    const code = '''
import 'package:flutter/widgets.dart';
Widget header() => const SizedBox();
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('header'), 'header'.length),
    ]);
  }

  Future<void> test_aPubspecThatIsNotAMapIsAProductionPackage() async {
    newFile('$testPackageRootPath/pubspec.yaml', '- not a map\n');
    const code = '''
import 'package:flutter/widgets.dart';
Widget header() => const SizedBox();
''';
    await assertDiagnostics(code, [
      lint(code.indexOf('header'), 'header'.length),
    ]);
  }

  Future<void> test_testsMayReturnWidgets() async {
    // A test's `Widget get app` builds the tree it pumps once; nothing
    // rebuilds it.
    final path = '$testPackageRootPath/test/page_test.dart';
    newFile(path, '''
import 'package:flutter/widgets.dart';
Widget get app => const SizedBox();
''');
    await assertNoDiagnosticsInFile(path);
  }
}
