import 'package:flutter/material.dart';

/// Wraps [child] and, while [busy] is true, dims it behind a modal barrier with
/// a progress indicator and optional [message].
class BusyOverlay extends StatelessWidget {
  const BusyOverlay({
    super.key,
    required this.busy,
    required this.child,
    this.message,
  });

  final bool busy;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (busy)
          Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      if (message != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          message!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
