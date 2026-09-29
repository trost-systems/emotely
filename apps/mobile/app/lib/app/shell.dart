import 'package:emotely/l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The two tabs a signed-in user lives in (ADR 0016): the journal, and
/// everything else under More. Each tab keeps its own stack — an entry
/// open on the journal stays open while the user visits More — and the
/// session and the consent screen are pushed above both, on the root
/// navigator, so the bar goes away while they are up. The destinations
/// are in the order of the shell's branches in `routes.dart`.
class const AppShell({
  required final StatefulNavigationShell navigationShell,
  super.key,
}) extends StatelessWidget {
  static const journalTabKey = Key('app_shell.journal');
  static const moreTabKey = Key('app_shell.more');

  @override
  Widget build(BuildContext context) => Scaffold(
    body: navigationShell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: navigationShell.currentIndex,
      // Tapping the tab already shown goes back to its first screen, as
      // the platforms' own tab bars do.
      onDestinationSelected: (index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
      destinations: [
        NavigationDestination(
          key: journalTabKey,
          icon: const Icon(Icons.menu_book_outlined),
          selectedIcon: const Icon(Icons.menu_book),
          label: context.l10n.journalTab,
        ),
        NavigationDestination(
          key: moreTabKey,
          icon: const Icon(Icons.more_horiz),
          label: context.l10n.moreTab,
        ),
      ],
    ),
  );
}
