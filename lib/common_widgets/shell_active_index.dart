import 'package:flutter/widgets.dart';

/// Exposes the shell's currently-active tab index to descendant tab screens.
///
/// Used so a tab can disable its Heroes while it sits offstage in the
/// indexed-stack shell — otherwise its Hero tags collide with routes pushed
/// over the shell (e.g. the province gallery), and on pop the heroes fly to
/// the offstage slots, leaving ghost images. See gallery_screen's HeroMode.
class ShellActiveIndex extends InheritedWidget {
  const ShellActiveIndex({
    required this.index,
    required super.child,
    super.key,
  });

  final int index;

  static int? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ShellActiveIndex>()
      ?.index;

  @override
  bool updateShouldNotify(ShellActiveIndex oldWidget) =>
      oldWidget.index != index;
}
