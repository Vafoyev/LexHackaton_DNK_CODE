import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'glass_surface.dart';

/// Standardized Light ↔ Dark circular curtain reveal controller.
///
/// Works with `MaterialApp.themeAnimationDuration = Duration.zero` so the live
/// tree swaps in a single frame behind the captured GPU snapshot while a silky
/// 560ms circular curtain sweeps cleanly with zero color-tween flicker:
/// - Light → Dark: Darkness spreads radially outward from the toggle button.
/// - Dark → Light: Darkness gathers/collapses back into the sun button as
///   light sweeps cleanly across the screen like an opening curtain.
class ThemeRevealScope extends StatefulWidget {
  const ThemeRevealScope({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
    required this.child,
  });

  final VoidCallback onToggleTheme;
  final bool isDark;
  final Widget child;

  static _ThemeRevealScopeState? _maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<_ThemeRevealScopeState>();
  }

  static void toggleFromContext(BuildContext buttonContext) {
    final scope = _maybeOf(buttonContext);
    if (scope == null) return;

    Offset? center;
    final renderObject = buttonContext.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      center = renderObject.localToGlobal(
        renderObject.size.center(Offset.zero),
      );
    }
    scope.triggerToggle(origin: center);
  }

  @override
  State<ThemeRevealScope> createState() => _ThemeRevealScopeState();
}

class _ThemeRevealScopeState extends State<ThemeRevealScope>
    with SingleTickerProviderStateMixin {
  final GlobalKey _boundaryKey = GlobalKey();
  late final AnimationController _anim;

  ui.Image? _snapshot;
  Offset _origin = Offset.zero;
  bool _switchingToDark = true;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _clearSnapshot();
        }
      });
  }

  @override
  void dispose() {
    _snapshot?.dispose();
    _snapshot = null;
    _anim.dispose();
    super.dispose();
  }

  void _clearSnapshot() {
    final img = _snapshot;
    _snapshot = null;
    if (mounted) {
      setState(() {});
    }
    img?.dispose();
  }

  Future<void> triggerToggle({Offset? origin}) async {
    if (_capturing || _anim.isAnimating) return;
    HapticFeedback.lightImpact();

    final boundary = _boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;

    if (boundary == null || !boundary.hasSize) {
      widget.onToggleTheme();
      return;
    }

    _capturing = true;
    try {
      final dpr = View.of(context).devicePixelRatio.clamp(1.0, 2.5);
      final image = await boundary.toImage(pixelRatio: dpr);
      if (!mounted) {
        image.dispose();
        return;
      }

      final size = boundary.size;
      _origin = origin ?? Offset(size.width - 36, 56);
      _switchingToDark = !widget.isDark;

      _snapshot?.dispose();
      setState(() {
        _snapshot = image;
      });

      // Switch the live theme immediately underneath the frozen snapshot
      widget.onToggleTheme();

      // Start the silky curtain animation immediately with zero delay
      _anim.forward(from: 0.0);
    } catch (_) {
      widget.onToggleTheme();
    } finally {
      _capturing = false;
    }
  }

  double _maxRadiusFor(Size size, Offset center) {
    final dx = math.max(center.dx, size.width - center.dx);
    final dy = math.max(center.dy, size.height - center.dy);
    return math.sqrt(dx * dx + dy * dy) + 16;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        alignment: Alignment.topLeft,
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            key: _boundaryKey,
            child: widget.child,
          ),
          if (_snapshot != null)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _anim,
                  builder: (context, _) {
                    final t = Curves.easeInOutCubic.transform(_anim.value);
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final size = constraints.biggest;
                        final maxR = _maxRadiusFor(size, _origin);
                        final radius =
                            _switchingToDark ? maxR * t : maxR * (1.0 - t);

                        return Stack(
                          alignment: Alignment.topLeft,
                          fit: StackFit.expand,
                          children: [
                            ClipPath(
                              clipper: _CircularCurtainClipper(
                                center: _origin,
                                radius: radius,
                                invertHole: _switchingToDark,
                              ),
                              child: RawImage(
                                image: _snapshot,
                                fit: BoxFit.fill,
                              ),
                            ),
                            if (t > 0.01 && t < 0.98)
                              CustomPaint(
                                painter: _CurtainRimPainter(
                                  center: _origin,
                                  radius: radius,
                                  color: _switchingToDark
                                      ? const Color(0xFF60A5FA)
                                      : const Color(0xFFFBBF24),
                                  opacity: math.sin(t * math.pi) * 0.58,
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Standardized Sun ↔ Moon animated toggle pill used uniformly across all screens.
class LexThemeTogglePill extends StatelessWidget {
  const LexThemeTogglePill({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    return Builder(
      builder: (btnCtx) => GlassPill(
        key: const Key('theme_toggle_pill'),
        padding: const EdgeInsets.all(8),
        onTap: () => ThemeRevealScope.toggleFromContext(btnCtx),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, anim) => RotationTransition(
            turns: Tween<double>(begin: 0.75, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            ),
            child: ScaleTransition(scale: anim, child: child),
          ),
          child: Icon(
            isDark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill,
            key: ValueKey(isDark),
            size: 15,
            color: isDark ? const Color(0xFFFBBF24) : c.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _CircularCurtainClipper extends CustomClipper<Path> {
  const _CircularCurtainClipper({
    required this.center,
    required this.radius,
    required this.invertHole,
  });

  final Offset center;
  final double radius;
  final bool invertHole;

  @override
  Path getClip(Size size) {
    final circle = Path()
      ..addOval(
        Rect.fromCircle(center: center, radius: radius.clamp(0.0, 4000.0)),
      );
    if (!invertHole) {
      return circle;
    }
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addPath(circle, Offset.zero);
  }

  @override
  bool shouldReclip(covariant _CircularCurtainClipper oldClipper) {
    return oldClipper.radius != radius ||
        oldClipper.center != center ||
        oldClipper.invertHole != invertHole;
  }
}

class _CurtainRimPainter extends CustomPainter {
  const _CurtainRimPainter({
    required this.center,
    required this.radius,
    required this.color,
    required this.opacity,
  });

  final Offset center;
  final double radius;
  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 1 || opacity <= 0.01) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = color.withValues(alpha: opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _CurtainRimPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.opacity != opacity ||
        oldDelegate.color != color;
  }
}
