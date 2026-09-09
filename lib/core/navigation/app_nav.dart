import 'package:flutter/material.dart';

import 'slide_push_route.dart';

/// Central navigation helper distinguishing the app's two transition
/// semantics (per instruction):
///
/// - [AppNav.push] — "going deeper" into a screen. Slides in from the
///   right, slides back out to the right on pop. Use for anything that
///   feels like a new destination (e.g. Dashboard -> Menu Management).
///
/// - [AppNav.showModal] — a temporary action layered on top of the
///   current screen (add-forms, option sheets). Slides up from the
///   bottom. The screen underneath stays exactly as it was — it is
///   genuinely still there in the widget tree, just visually covered,
///   consistent with "stack" semantics (nothing below gets unmounted).
///
/// Centralizing both here means every feature screen gets the same
/// transition behavior without re-specifying animation details at each
/// call site.
class AppNav {
  AppNav._();

  static Future<T?> push<T>(BuildContext context, WidgetBuilder builder) {
    return Navigator.of(context).push<T>(SlidePushRoute<T>(builder: builder));
  }

  static Future<T?> showModal<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }
}
