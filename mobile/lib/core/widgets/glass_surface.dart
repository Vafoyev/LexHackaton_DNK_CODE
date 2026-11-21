import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Soft iOS mesh gradient backdrop with role-aware ambient orbs.
/// Frosted GlassCards above this backdrop visibly refract Sapphire (Jismoniy)
/// or Deep Emerald (Yuridik) light.
class AmbientGlassBackdrop extends StatelessWidget {
  const AmbientGlassBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      color: c.canvasBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -110,
            right: -70,
            child: _AmbientOrb(size: 320, color: c.ambientOrbA),
          ),
          Positioned(
            top: 210,
            left: -120,
            child: _AmbientOrb(
              size: 290,
              color: c.ambientOrbB.withValues(alpha: 0.65),
            ),
          ),
          Positioned(
            bottom: -90,
            right: -40,
            child: _AmbientOrb(
              size: 270,
              color: c.ambientOrbA.withValues(alpha: 0.55),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 380),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.85),
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
    final fill = tintColor ?? c.glassFill;
    final border = borderColor ?? c.glassBorder;

    Widget content = BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
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
              color: Colors.black.withValues(alpha: 0.05),
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
