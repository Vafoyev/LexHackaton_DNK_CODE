import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Standardized senior-grade modal bottom sheet launcher for LexGuard AI.
///
/// Always pushes onto the root navigator (`useRootNavigator: true`) so modals
/// ALWAYS appear cleanly above the floating bottom navigation bar, with
/// uniform blurred backdrop scrim, safe-area / keyboard insets, and smooth
/// standardized motion in both Light and Dark modes.
Future<T?> showLexModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool wrapInGlassCard = true,
  EdgeInsetsGeometry contentPadding = const EdgeInsets.fromLTRB(20, 12, 20, 20),
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: isDark ? 0.62 : 0.42),
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 340),
      reverseDuration: Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ),
    builder: (ctx) {
      if (!wrapInGlassCard) {
        return builder(ctx);
      }
      return _LexSheetFrame(
        contentPadding: contentPadding,
        child: builder(ctx),
      );
    },
  );
}

class _LexSheetFrame extends StatelessWidget {
  const _LexSheetFrame({
    required this.child,
    required this.contentPadding,
  });

  final Widget child;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        bottomInset + (bottomSafe > 0 ? bottomSafe + 4 : 12),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.16),
                blurRadius: 34,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(
                padding: contentPadding,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xF2121A26)
                      : const Color(0xFAFFFFFF),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.14)
                        : c.glassBorder,
                    width: 1.1,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: c.textSecondary.withValues(alpha: 0.30),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
