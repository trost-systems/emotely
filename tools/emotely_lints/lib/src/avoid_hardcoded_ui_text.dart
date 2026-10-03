import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:emotely_lints/src/flutter_types.dart';

/// A string a user would read, written into the UI as a literal instead of
/// coming from the package's ARB files (ADR 0020).
///
/// Reported: a string literal that holds a letter, given in a package's
/// `lib/` to a `String` parameter
///
/// - of a widget constructor, or of a method on a widget class, except for
///   the few parameters that are identifiers rather than text
///   ([_identifierParameters]); or
/// - of any other Flutter API, when the parameter is one of the names Flutter
///   gives text ([_textParameters]: `label`, `hintText`, `message`, …).
///
/// Not reported: tests, strings without a letter (punctuation, digits,
/// emoji), URLs and asset paths, and every class that is neither a widget
/// nor Flutter's (an exception's message is for error tracking).
class AvoidHardcodedUiText() extends AnalysisRule {
  this
    : super(
        name: 'avoid_hardcoded_ui_text',
        description:
            'User-facing text comes from the ARB files, never from a literal.',
      );

  /// One instance, so that `// ignore: emotely_lints/avoid_hardcoded_ui_text`
  /// matches it.
  static const code = LintCode(
    'avoid_hardcoded_ui_text',
    'A user-facing string is written into the UI as a literal.',
    correctionMessage:
        "Add it to the package's English ARB file with a description, "
        'translate it in every other ARB file, and read it through the '
        "package's localizations class (ADR 0020).",
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    // Tests assert on literal text all the time; only lib/ ships.
    if (context.isInLibDir) {
      final visitor = _Visitor(this);
      registry
        ..addInstanceCreationExpression(this, visitor)
        ..addMethodInvocation(this, visitor);
    }
  }
}

class _Visitor(final AnalysisRule rule) extends SimpleAstVisitor<void> {
  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) =>
      _check(node.constructorName.element?.enclosingElement, node.argumentList);

  @override
  void visitMethodInvocation(MethodInvocation node) =>
      _check(node.methodName.element?.enclosingElement, node.argumentList);

  void _check(Element? owner, ArgumentList arguments) {
    if (owner is! InterfaceElement) {
      return;
    }
    final ownerIsWidget = isWidget(owner);
    if (!ownerIsWidget && (!isFlutter(owner) || _isThrowable(owner))) {
      return;
    }
    arguments.arguments
        .where((argument) => _isText(argument, isWidget: ownerIsWidget))
        .forEach((argument) => rule.reportAtNode(argument.argumentExpression));
  }

  /// Whether [argument] is a literal that reads as language, given to a
  /// parameter that shows text: on a widget any `String` parameter but an
  /// identifier, elsewhere only the parameters Flutter names for text.
  bool _isText(Argument argument, {required bool isWidget}) {
    final parameter = argument.correspondingParameter;
    final text = _literalText(argument.argumentExpression);
    if (text == null || parameter == null || !parameter.type.isDartCoreString) {
      return false;
    }
    final name = parameter.name ?? '';
    final showsText = isWidget
        ? !_identifierParameters.contains(name)
        : _textParameters.contains(name);
    return showsText && _readsAsLanguage(text);
  }
}

/// The text written into the code for [value]: a string literal's own text,
/// or the value of a `const` it names — `Text(consentTitle)` with the words
/// one declaration away is the same literal. Anything computed at run time
/// (a localizations getter, a parameter) is `null`.
String? _literalText(Expression value) => switch (value) {
  StringLiteral() => _ownText(value),
  Identifier(:final element?) => _constantText(element),
  _ => null,
};

String? _constantText(Element element) {
  final variable = switch (element) {
    PropertyAccessorElement(:final variable) => variable,
    VariableElement() => element,
    _ => null,
  };
  return variable != null && variable.isConst
      ? variable.computeConstantValue()?.toStringValue()
      : null;
}

/// Parameters of a widget that name something rather than say something.
const _identifierParameters = {
  'debugLabel',
  'fontFamily',
  'identifier',
  'package',
  'restorationId',
  'semanticsIdentifier',
  // Cloudflare Turnstile's public widget key (#94).
  'siteKey',
};

/// Parameters through which Flutter's non-widget classes show text:
/// `InputDecoration`, `TextSpan`, `SemanticsService.announce` and the like.
const _textParameters = {
  'counterText',
  'errorText',
  'helperText',
  'hint',
  'hintText',
  'label',
  'labelText',
  'message',
  'prefixText',
  'semanticCounterText',
  'semanticLabel',
  'semanticsLabel',
  'subtitle',
  'suffixText',
  'text',
  'title',
  'tooltip',
};

/// A letter anywhere in the literal's own text: punctuation, digits, emoji
/// and interpolated values alone are not language.
final _letter = RegExp(r'\p{L}', unicode: true);

/// A URL or a path: no blank in it, and a slash.
final _pathLike = RegExp(r'^[^\s/]*/\S*$');

bool _readsAsLanguage(String text) =>
    _letter.hasMatch(text) && !_pathLike.hasMatch(text);

/// Exceptions and errors: their messages are for logs and error tracking,
/// whatever the parameter is called (`PlatformException(message:)`).
bool _isThrowable(InterfaceElement element) => element.allSupertypes.any(
  (type) =>
      const {'Exception', 'Error'}.contains(type.element.name) &&
      type.element.library.isDartCore,
);

String _ownText(StringLiteral literal) => switch (literal) {
  SimpleStringLiteral(:final value) => value,
  AdjacentStrings(:final strings) => strings.map(_ownText).join(),
  StringInterpolation(:final elements) =>
    elements.whereType<InterpolationString>().map((part) => part.value).join(),
};
