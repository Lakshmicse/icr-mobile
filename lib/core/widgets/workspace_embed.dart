import 'package:flutter/widgets.dart';

/// Marks a screen shown as a tab of a workspace (`WorkspaceScreen`, opened from the profile menu's workspaces):
/// the workspace draws one bar — back, its name — and the row of tabs for all of them, so a screen's own top bar
/// steps aside under it. `TitleBar` and `AccountBar` keep only their search and actions — the tab names the page,
/// so its own title is not drawn again (owner, 9 Nov 2026: "the tab is telling the title, there would be no use of
/// the title again, wherever it is remove it") — and the Events header goes. A screen pushed from inside a tab is a
/// route of its own, outside this, and draws its bar as always.
class WorkspaceEmbed extends InheritedWidget {
  const WorkspaceEmbed({super.key, required super.child, this.openTab});

  /// Switches the workspace to its tab for a website path (`/mentorship/mentors`), answering whether it has one: a
  /// page's "Find a mentor" lands on the workspace's own Find a mentor tab, not on a second copy pushed over it.
  final bool Function(String path)? openTab;

  /// Whether [context] is inside a workspace's tab.
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<WorkspaceEmbed>() != null;

  /// Moves the workspace around [context] to its tab for [path]; false when [context] is in no workspace or the
  /// workspace has no tab for it (the caller opens the page itself then).
  static bool openTabFor(BuildContext context, String path) =>
      context.getInheritedWidgetOfExactType<WorkspaceEmbed>()?.openTab?.call(path) ?? false;

  @override
  bool updateShouldNotify(WorkspaceEmbed oldWidget) => false;
}
