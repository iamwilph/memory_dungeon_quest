// ErrorBoundary — catches exceptions during the child's build phase and
// displays a styled error panel with an optional retry action.
//
// Usage:
//   ErrorBoundary(
//     child: (context) => MyScreen(),
//     onRetry: () => Navigator.pushReplacement(context, ...),
//   )

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../widgets/hud_element.dart';
import '../../theme/dungeon_theme.dart';

/// A widget that wraps [child] and catches any exceptions thrown during
/// the child's [WidgetBuilder] invocation.
///
/// When an error occurs, the boundary displays a styled error panel with
/// the error message and an optional retry button.
class ErrorBoundary extends StatefulWidget {
  /// The widget builder that produces the child subtree.
  ///
  /// Using [WidgetBuilder] instead of [Widget] allows us to call the
  /// builder within a try/catch block in [State.build], catching any
  /// exceptions thrown during the child's build phase.
  final WidgetBuilder child;

  /// Optional builder that produces an error widget when the child throws.
  ///
  /// If [errorBuilder] is null, a default styled error panel is shown.
  final Widget Function(Object error, StackTrace stack)? errorBuilder;

  /// Called when an error occurs. Receives the error and stack trace.
  final void Function(Object error, StackTrace stack)? onError;

  /// Optional callback invoked when the user taps the retry button.
  final VoidCallback? onRetry;

  /// Creates an [ErrorBoundary].
  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onError,
    this.onRetry,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stack;

  /// Handles an error by updating state to show the error UI.
  void _handleError(Object error, StackTrace stack) {
    setState(() {
      _error = error;
      _stack = stack;
    });
    widget.onError?.call(error, stack);
  }

  @override
  Widget build(BuildContext context) {
    // If we have a stored error, show the error UI.
    if (_error != null) {
      return widget.errorBuilder?.call(_error!, _stack!) ??
          _defaultErrorWidget(context, _error!, _stack, widget.onRetry);
    }

    // Attempt to build the child. If it throws, catch and display the error.
    try {
      return widget.child(context);
    } catch (error, stack) {
      _handleError(error, stack);
      return widget.errorBuilder?.call(error, stack) ??
          _defaultErrorWidget(context, error, stack, widget.onRetry);
    }
  }
}

/// Default error panel styled to match the dungeon theme.
Widget _defaultErrorWidget(
  BuildContext context,
  Object error,
  StackTrace? stack,
  VoidCallback? onRetry,
) {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
      ),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: HudElement(
            borderRadius: 16.0,
            padding: const EdgeInsets.all(24.0),
            seed: 999,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Error icon
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Color(0xFFE74C3C),
                ),
                const SizedBox(height: 16),

                // Error title
                Text(
                  'CHAMBER COLLAPSED',
                  style: DungeonTheme.getTitleStyle(
                    context,
                    const Color(0xFFE74C3C),
                  ),
                ),
                const SizedBox(height: 8),

                // Short error message (truncated)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    _truncateErrorMessage(error.toString(), 120),
                    textAlign: TextAlign.center,
                    style: DungeonTheme.getBodyStyle(
                      12.0,
                      Colors.white70,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Debug info (collapsed by default)
                if (kDebugMode)
                  CollapsibleDebugInfo(error: error, stack: stack),

                const SizedBox(height: 24),

                // Retry button
                if (onRetry != null)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE74C3C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onPressed: onRetry,
                    child: Text(
                      'RETRY',
                      style: DungeonTheme.getBodyStyle(
                        12,
                        Colors.white,
                        weight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Truncates an error message to [maxLength] characters, appending '…'.
String _truncateErrorMessage(String message, int maxLength) {
  if (message.length <= maxLength) return message;
  return '${message.substring(0, maxLength)}…';
}

/// Collapsible debug info panel (visible only in debug mode).
class CollapsibleDebugInfo extends StatefulWidget {
  final Object error;
  final StackTrace? stack;

  const CollapsibleDebugInfo({
    super.key,
    required this.error,
    this.stack,
  });

  @override
  State<CollapsibleDebugInfo> createState() => _CollapsibleDebugInfoState();
}

class _CollapsibleDebugInfoState extends State<CollapsibleDebugInfo> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          onPressed: () => setState(() => _isExpanded = !_isExpanded),
          child: Text(
            _isExpanded ? 'HIDE DEBUG INFO' : 'SHOW DEBUG INFO',
            style: DungeonTheme.getBodyStyle(
              10,
              const Color(0xFF5A6B7C),
              weight: FontWeight.w600,
            ),
          ),
        ),
        if (_isExpanded)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.error.toString(),
                      style: DungeonTheme.getBodyStyle(
                        9.5,
                        const Color(0xFFE67E22),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.stack?.toString() ?? '',
                      style: DungeonTheme.getBodyStyle(
                        9,
                        Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}