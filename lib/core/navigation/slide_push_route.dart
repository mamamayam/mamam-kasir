import 'package:flutter/material.dart';

/// "Push" navigation — slides in from the right, slides back out to the
/// right on pop. This is the standard transition for "going deeper into a
/// menu" (per instruction: Stack Navigation, Slide In/Push = right-to-left
/// entry, and the reverse on the way back).
///
/// Only the incoming/outgoing route itself is animated here via
/// [animation] (this route's own lifecycle: 0 -> 1 on push, 1 -> 0 on
/// pop). Whatever sits underneath in the stack (a screen, or a bottom
/// sheet route per the app's stack-navigation model) is intentionally
/// left alone — it doesn't need its own transition, it's simply covered
/// by this route sliding in over it, and revealed again as this route
/// slides back out on pop. [secondaryAnimation] is deliberately unused:
/// it animates this route only when something else is pushed ON TOP of
/// it, which isn't a case this app's navigation model needs a custom
/// effect for.
///
/// Use via [AppNav.push] rather than constructing directly, so the whole
/// app stays consistent without every call site re-specifying curves/
/// durations.
class SlidePushRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  SlidePushRoute({required this.builder})
      : super(
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            final offset = Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved);

            return SlideTransition(position: offset, child: child);
          },
        );
}
