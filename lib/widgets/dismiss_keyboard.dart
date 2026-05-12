import 'package:flutter/material.dart';

/// Wraps a subtree so tapping any empty area dismisses the focused
/// TextField. This gives users a reliable way out of the keyboard and
/// back to the navigation chrome — particularly the bottom navigation
/// bar, which iOS hides whenever the soft keyboard is on screen.
///
/// We use `HitTestBehavior.opaque` so taps that hit padding or empty
/// space register as gestures here, while TextFields and buttons still
/// receive their taps first because they consume hit testing before
/// the event reaches this detector.
class DismissKeyboard extends StatelessWidget {
  const DismissKeyboard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}
