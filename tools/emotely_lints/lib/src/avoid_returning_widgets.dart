import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/workspace/workspace.dart';
import 'package:emotely_lints/src/flutter_types.dart';
import 'package:yaml/yaml.dart';

/// A function, method or getter that returns a widget, where a widget class
/// belongs.
///
/// A widget built by a helper call is part of its caller's `build`: it has
/// no element of its own, cannot be `const`, and is rebuilt whenever the
/// caller is. A `StatelessWidget` or `StatefulWidget` in its place is
/// something Flutter can cache, compare and skip.
///
/// Reported, in a package's `lib/`: a top-level or local function, a
/// method, a getter (static, instance or extension) whose return type,
/// declared or inferred, is Flutter's `Widget` or a subtype of it, nullable
/// or not. An abstract member of our own is reported too: the decision to
/// have implementers return widgets is made there, once.
///
/// Not reported:
///
/// - a member that overrides one a supertype declares (`build`, a router's
///   `buildPage`, our own abstract member's implementations): its signature
///   is the supertype's, not this declaration's to change;
/// - a closure, a builder callback included: the builder widget calls it
///   from an element of its own, which is the framework's way to defer
///   building;
/// - tests, whose `Widget get app` builds the tree they pump once, and
///   test-support packages: a package with `flutter_test` or `test` in its
///   `dependencies` (not `dev_dependencies`) can never ship in the app, so
///   its `lib/` is for tests too (`testing`'s `pageUnderTest`).
class AvoidReturningWidgets() extends AnalysisRule {
  this
    : super(
        name: 'avoid_returning_widgets',
        description:
            'Build a widget in a widget class, never in a function that '
            'returns one.',
      );

  /// One instance, so that `// ignore: emotely_lints/avoid_returning_widgets`
  /// matches it.
  static const code = LintCode(
    'avoid_returning_widgets',
    'A function returns a widget.',
    correctionMessage:
        'Extract it into a StatelessWidget or StatefulWidget, so Flutter can '
        'cache it and skip rebuilding it.',
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (context.isInLibDir && !_isTestSupport(context.package)) {
      final visitor = _Visitor(this);
      registry
        ..addFunctionDeclaration(this, visitor)
        ..addMethodDeclaration(this, visitor);
    }
  }
}

class _Visitor(final AnalysisRule rule) extends SimpleAstVisitor<void> {
  @override
  void visitFunctionDeclaration(FunctionDeclaration node) =>
      _check(node.declaredFragment?.element, node.name);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final element = node.declaredFragment?.element;
    if (element != null && !_overrides(element)) {
      _check(element, node.name);
    }
  }

  void _check(ExecutableElement? element, Token name) {
    final returned = element?.returnType.element;
    if (returned is InterfaceElement && isWidget(returned)) {
      rule.reportAtToken(name);
    }
  }
}

/// Test dependencies that only test code can have in `dependencies`.
const _testFrameworks = {'flutter_test', 'test'};

/// Whether [package] is test support rather than production code: it
/// depends on a test framework outside `dev_dependencies`, so the app can
/// never ship it (in this workspace, `packages/utility/testing`). Its
/// helpers build the tree a test pumps once, like a test's own.
bool _isTestSupport(WorkspacePackage? package) {
  final pubspec = package?.root.getFile('pubspec.yaml');
  if (pubspec == null || !pubspec.exists) {
    return false;
  }
  final dependencies = switch (loadYaml(pubspec.readAsStringSync())) {
    final YamlMap fields => fields['dependencies'],
    _ => null,
  };
  return dependencies is YamlMap &&
      _testFrameworks.any(dependencies.containsKey);
}

/// Whether [member] overrides one its class inherits: from a superclass, a
/// mixin, an interface or a mixin's `on` type.
bool _overrides(ExecutableElement member) {
  final owner = member.enclosingElement;
  final name = member.name;
  return owner is InterfaceElement &&
      name != null &&
      owner.getInheritedMember(Name.forLibrary(owner.library, name)) != null;
}
