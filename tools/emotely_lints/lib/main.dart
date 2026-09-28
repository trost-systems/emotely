import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:emotely_lints/src/avoid_hardcoded_ui_text.dart';

/// The entry point the analysis server looks for: it compiles this library
/// and reads the top-level [plugin].
final plugin = EmotelyLints();

/// emotely's own lint rules. Each is registered as a lint, so it is off until
/// `diagnostics:` in `apps/mobile/packages/utility/analysis/lib/plugins.yaml`
/// turns it on.
class EmotelyLints() extends Plugin {
  @override
  String get name => 'emotely_lints';

  @override
  void register(PluginRegistry registry) {
    registry.registerLintRule(AvoidHardcodedUiText());
  }
}
