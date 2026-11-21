import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

enum LexToastType { success, info, warning, error }

/// Senior iOS/Dynamic-Island style floating top glass toast.
/// Never collides with the bottom floating navigation bar.
class LexToast {
  const LexToast._();

  static OverlayEntry? _activeEntry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context,
    String message, {
    LexToastType type = LexToastType.info,
    Duration duration = const Duration(milliseconds: 2400),
  }) {
    _dismissTimer?.cancel();
    _activeEntry?.remove();
    _activeEntry = null;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    if (type == LexToastType.error || type == LexToastType.warning) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _LexToastOverlay(
        message: message,
        type: type,
        onDismiss: () {
          _dismissTimer?.cancel();
          if (_activeEntry == entry) {
            _activeEntry = null;
          }
          entry.remove();
        },
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(duration, () {
      if (_activeEntry == entry) {
        _activeEntry = null;
        entry.remove();
      }
    });
  }
}

class _LexToastOverlay extends StatefulWidget {
  const _LexToastOverlay({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  final String message;
  final LexToastType type;
  final VoidCallback onDismiss;

  @override
  State<_LexToastOverlay> createState() => _LexToastOverlayState();
}

class _LexToastOverlayState extends State<_LexToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.45),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPad = MediaQuery.paddingOf(context).top;

    final (icon, accent) = switch (widget.type) {
      LexToastType.success => (
          CupertinoIcons.checkmark_circle_fill,
          c.greenText,
        ),
      LexToastType.warning => (
          CupertinoIcons.exclamationmark_triangle_fill,
          c.yellowText,
        ),
      LexToastType.error => (
          CupertinoIcons.xmark_circle_fill,
          c.redText,
        ),
      LexToastType.info => (
          CupertinoIcons.info_circle_fill,
          c.rolePrimary,
        ),
    };

    return Positioned(
      top: topPad + 10,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Dismissible(
              key: UniqueKey(),
              direction: DismissDirection.up,
              onDismissed: (_) => widget.onDismiss(),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: GestureDetector(
                    onTap: widget.onDismiss,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.45 : 0.14,
                            ),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xF0151E2E)
                                  : const Color(0xFAFFFFFF),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.14),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(icon, size: 16, color: accent),
                                ),
                                const SizedBox(width: 11),
                                Flexible(
                                  child: Text(
                                    widget.message,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      height: 1.3,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
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
