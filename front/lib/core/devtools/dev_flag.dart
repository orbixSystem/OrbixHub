import 'package:flutter/foundation.dart';

/// Dev-tools are ON in debug/profile by default and OFF in release unless
/// explicitly enabled via --dart-define=DEV_TOOLS=true. A const so the beetle
/// and its code are tree-shaken out of release builds.
const bool kDevTools =
    bool.fromEnvironment('DEV_TOOLS', defaultValue: !kReleaseMode);
