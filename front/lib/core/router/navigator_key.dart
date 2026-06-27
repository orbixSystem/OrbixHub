import 'package:flutter/widgets.dart';

/// The app's root navigator key. Lets global overlay controls (rendered above
/// the Navigator via MaterialApp.builder) open modals/sheets through the
/// Navigator's own overlay context.
final rootNavigatorKey = GlobalKey<NavigatorState>();
