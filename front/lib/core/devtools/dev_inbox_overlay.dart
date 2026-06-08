import 'package:flutter/material.dart';

import 'dev_flag.dart';
import 'dev_inbox_modal.dart';

/// Wraps the whole app and — only when [kDevTools] is true — paints a small
/// floating "beetle" button in the top-right corner that opens the dev inbox.
///
/// In release builds [kDevTools] is a compile-time `false`, so the entire
/// beetle subtree below is dead code and gets tree-shaken out.
class DevInboxOverlay extends StatelessWidget {
  const DevInboxOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kDevTools) return child;

    final colors = Theme.of(context).colorScheme;

    // Only the Positioned button consumes pointer events; the rest of the
    // Stack passes touches straight through to [child].
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: Material(
                color: colors.primary,
                elevation: 4,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openInbox(context),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.bug_report,
                      size: 20,
                      color: colors.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openInbox(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (_) => const DevInboxModal(),
    );
  }
}
