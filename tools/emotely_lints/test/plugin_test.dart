import 'package:analysis_server_plugin/registry.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:emotely_lints/main.dart';
import 'package:emotely_lints/src/avoid_hardcoded_ui_text.dart';
import 'package:test/test.dart';

/// Records what the plugin registers; the plugin calls nothing else.
class _Registry() implements PluginRegistry {
  final lintRules = <AbstractAnalysisRule>[];
  final warningRules = <AbstractAnalysisRule>[];

  @override
  void registerLintRule(AbstractAnalysisRule rule) => lintRules.add(rule);

  @override
  void registerWarningRule(AbstractAnalysisRule rule) => warningRules.add(rule);

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group(EmotelyLints, () {
    test('is found under the name analysis_options.yaml gives it', () {
      // `plugins: emotely_lints:` and every `// ignore: emotely_lints/…`
      // must use this name.
      expect(plugin.name, 'emotely_lints');
    });

    test('registers every rule as a lint, off until enabled', () {
      final registry = _Registry();

      plugin.register(registry);

      expect(registry.lintRules.map((rule) => rule.name), [
        AvoidHardcodedUiText.code.lowerCaseName,
      ]);
      expect(registry.warningRules, isEmpty);
    });
  });
}
