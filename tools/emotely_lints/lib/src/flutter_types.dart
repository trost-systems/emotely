import 'package:analyzer/dart/element/element.dart';

/// Libraries whose classes are Flutter's, in the SDK or in the standalone
/// Material and Cupertino packages the app uses.
const _flutterPackages = {'flutter', 'material_ui', 'cupertino_ui'};

/// Whether [element] is declared by Flutter (see [_flutterPackages]).
bool isFlutter(InterfaceElement element) {
  final uri = element.library.uri;
  return uri.isScheme('package') &&
      _flutterPackages.contains(uri.pathSegments.first);
}

/// Whether [element] is Flutter's `Widget` or a subtype of it.
bool isWidget(InterfaceElement element) => [
  element.thisType,
  ...element.allSupertypes,
].any((type) => type.element.name == 'Widget' && isFlutter(type.element));
