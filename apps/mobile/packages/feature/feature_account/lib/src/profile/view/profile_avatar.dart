import 'package:material_ui/material_ui.dart';

/// The user's initial in a circle: the first character they see of their
/// name (a grapheme, so an emoji or an accented letter stays whole),
/// uppercased — or a person when there is no name yet.
class const ProfileAvatar({
  required final String? name,
  required final double radius,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initial = name?.characters.firstOrNull?.toUpperCase();
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        child: initial == null
            ? Icon(Icons.person_outline, size: radius)
            : Text(initial, style: TextStyle(fontSize: radius)),
      ),
    );
  }
}
