import 'package:material_ui/material_ui.dart';

/// Opens what [builder] returns as a modal bottom sheet, and completes with
/// what the sheet is popped with: the one way the app opens a sheet, which
/// the `no-raw-bottom-sheet` ast-grep rule holds every other call to.
///
/// The sheet sits on the bottom edge, as tall as its content and never
/// under the status bar, and rises with the keyboard, so a text field in it
/// and whatever the sheet shows above that field stay in view and tappable
/// (#308). Material's own sheet does not: it lays out against the whole
/// screen, keyboard or not, and is capped at 9/16 of it unless scroll
/// controlled, a height a sheet lifted by a keyboard soon outgrows.
///
/// The content sees the keyboard as already avoided, so nothing in it lifts
/// itself a second time.
Future<T?> showSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _AboveKeyboard(child: Builder(builder: builder)),
);

/// Lifts [child] by the keyboard's height and hides that height from it.
class const _AboveKeyboard({required final Widget child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: child,
    ),
  );
}
