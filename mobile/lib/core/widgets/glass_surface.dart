import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Soft iOS mesh gradient backdrop with role-aware ambient orbs.
/// Frosted GlassCards above this backdrop gently refract Sapphire (Jismoniy)
/// or Deep Emerald (Yuridik) light without visual noise.
class AmbientGlassBackdrop extends StatelessWidget {
  const AmbientGlassBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAlpha = isDark ? 0.16 : 0.14;
    final secondaryAlpha = isDark ? 0.10 : 0.08;

    return Container(
      color: c.canvasBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -140,
            right: -90,
            child: _AmbientOrb(
              size: 340,
              color: c.ambientOrbA.withValues(alpha: primaryAlpha),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: _AmbientOrb(
              size: 300,
              color: c.ambientOrbB.withValues(alpha: secondaryAlpha),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Performance-isolated Apple iOS frosted glass container (`RepaintBoundary` + `BackdropFilter`).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.blurSigma = 20,
    this.tintColor,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blurSigma;
  final Color? tintColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = tintColor ?? c.glassFill;
    final border = borderColor ?? c.glassBorder;

    Widget content = BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              fill,
              fill.withValues(alpha: (fill.a * 0.78).clamp(0.0, 1.0)),
            ],
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: border, width: 1.0),
        ),
        child: child,
      ),
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: content,
        ),
      );
    }

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: content,
        ),
      ),
    );
  }
}

/// Compact frosted glass pill for status indicators, language toggle & role chips.
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    this.tintColor,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tintColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final fill = tintColor ?? c.glassFillStrong;
    final border = borderColor ?? c.glassBorder;

    Widget body = BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: child,
      ),
    );

    if (onTap != null) {
      body = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: body,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: body,
    );
  }
}
