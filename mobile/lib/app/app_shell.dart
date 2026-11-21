import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/app_strings.dart';
import '../core/l10n/uzbek_alphabet.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/glass_surface.dart';
import '../features/contracts/domain/entities/lex_models.dart';
import '../features/scanner_upload/presentation/direct_scan_launcher.dart';
import '../features/scanner_upload/presentation/scan_upload_sheet.dart';
import '../features/session/presentation/cubit/session_cubit.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with TickerProviderStateMixin {
  bool _scanMenuOpen = false;
  late final AnimationController _scanAnim;
  late final AnimationController _pulseAnim;

  @override
  void initState() {
    super.initState();
    _scanAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );
  }

  @override
  void dispose() {
    _pulseAnim.dispose();
    _scanAnim.dispose();
    super.dispose();
  }

  void _toggleScanMenu() {
    HapticFeedback.mediumImpact();
    setState(() => _scanMenuOpen = !_scanMenuOpen);
    if (_scanMenuOpen) {
      _scanAnim.forward();
      _pulseAnim.repeat(reverse: true);
    } else {
      _scanAnim.reverse();
      _pulseAnim.stop();
      _pulseAnim.reset();
    }
  }

  void _closeScanMenu() {
    if (!_scanMenuOpen) return;
    setState(() => _scanMenuOpen = false);
    _scanAnim.reverse();
    _pulseAnim.stop();
    _pulseAnim.reset();
  }

  void _go(int idx) {
    _closeScanMenu();
    widget.navigationShell.goBranch(
      idx,
      initialLocation: idx == widget.navigationShell.currentIndex,
    );
  }

  void _openQuickScan({required bool focusCamera}) {
    HapticFeedback.lightImpact();
    _closeScanMenu();
    if (focusCamera) {
      DirectScanLauncher.captureCameraAndAnalyze(context);
    } else {
      DirectScanLauncher.pickFileAndAnalyze(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final session = context.watch<SessionCubit>().state;
    final lang = session.lang;
    final script = session.uzbekScript;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isFullDesktop = constraints.maxWidth >= 840;
        if (isFullDesktop) {
          return AmbientGlassBackdrop(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Column(
                children: [
                  _FullDesktopTopBar(
                    segment: session.segment,
                    lang: lang,
                    script: script,
                    onTogglePhone: () =>
                        context.read<SessionCubit>().toggleDesktopFrame(),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        _DesktopGlassRail(
                          currentIndex: widget.navigationShell.currentIndex,
                          lang: lang,
                          script: script,
                          onSelect: _go,
                          onScan: () => ScanUploadSheet.show(context),
                        ),
                        Expanded(child: widget.navigationShell),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final bottomPad = MediaQuery.paddingOf(context).bottom;

        // Authentic iPhone Liquid Glass Shell: stadium pill navbar + upward quick scan popup.
        return AmbientGlassBackdrop(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              fit: StackFit.expand,
              children: [
                widget.navigationShell,
                AnimatedBuilder(
                  animation: Listenable.merge([_scanAnim, _pulseAnim]),
                  builder: (context, _) {
                    final rawT = _scanAnim.value;
                    if (!_scanMenuOpen && rawT == 0.0) {
                      return const SizedBox.shrink();
                    }

                    final scrimT = Curves.easeOut.transform(rawT);
                    final leftProgress = const Interval(
                      0.0,
                      0.86,
                      curve: Curves.easeOutBack,
                    ).transform(rawT);
                    final leftFade = const Interval(
                      0.0,
                      0.55,
                      curve: Curves.easeOut,
                    ).transform(rawT);

                    final rightProgress = const Interval(
                      0.14,
                      1.0,
                      curve: Curves.easeOutBack,
                    ).transform(rawT);
                    final rightFade = const Interval(
                      0.14,
                      0.70,
                      curve: Curves.easeOut,
                    ).transform(rawT);

                    final rippleT = const Interval(
                      0.0,
                      0.75,
                      curve: Curves.easeOutCubic,
                    ).transform(rawT);

                    final pulseWave = math.sin(_pulseAnim.value * math.pi);
                    final floatOffset =
                        _scanMenuOpen ? (pulseWave * 3.5) : 0.0;
                    final glowBoost =
                        _scanMenuOpen ? (0.85 + 0.30 * pulseWave) : 1.0;

                    final centerX = constraints.maxWidth / 2;
                    final originBottom = bottomPad + 16.0;
                    const orbSize = 66.0;
                    const slotWidth = 96.0;
                    const spreadX = 62.0;
                    const liftY = 86.0;

                    final leftArcX = -spreadX * leftProgress;
                    final leftArcY = liftY * leftProgress +
                        math.sin(leftProgress.clamp(0.0, 1.0) * math.pi) * 10 +
                        floatOffset;

                    final rightArcX = spreadX * rightProgress;
                    final rightArcY = liftY * rightProgress +
                        math.sin(rightProgress.clamp(0.0, 1.0) * math.pi) * 10 -
                        floatOffset;

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        IgnorePointer(
                          ignoring: !_scanMenuOpen,
                          child: GestureDetector(
                            key: const Key('scan_menu_scrim'),
                            behavior: HitTestBehavior.opaque,
                            onTap: _closeScanMenu,
                            child: scrimT > 0.01
                                ? BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 5.0 * scrimT,
                                      sigmaY: 5.0 * scrimT,
                                    ),
                                    child: ColoredBox(
                                      color: Colors.black.withValues(
                                        alpha: (isDark ? 0.52 : 0.34) * scrimT,
                                      ),
                                    ),
                                  )
                                : const SizedBox.expand(),
                          ),
                        ),
                        // Expanding ripple ring radiating from the center scan orb
                        if (rippleT > 0.01 && rippleT < 0.99)
                          Positioned(
                            left: centerX - (26 + 58 * rippleT),
                            bottom: originBottom + 26 - (26 + 58 * rippleT),
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: (1.0 - rippleT) * 0.45,
                                child: Container(
                                  width: (26 + 58 * rippleT) * 2,
                                  height: (26 + 58 * rippleT) * 2,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: c.rolePrimary,
                                      width: 2.0 * (1.0 - rippleT) + 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Left Radial Orb: Upload / File (Sapphire Blue glow)
                        Positioned(
                          left: centerX + leftArcX - slotWidth / 2,
                          bottom: originBottom + leftArcY,
                          width: slotWidth,
                          child: IgnorePointer(
                            ignoring: !_scanMenuOpen,
                            child: Opacity(
                              opacity: leftFade.clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale:
                                    (0.32 + 0.68 * leftProgress).clamp(0.2, 1.15),
                                child: Transform.rotate(
                                  angle: -0.35 * (1.0 - leftProgress.clamp(0.0, 1.0)),
                                  child: _RadialScanOrb(
                                    key: const Key('scan_quick_upload'),
                                    size: orbSize,
                                    icon: CupertinoIcons.photo,
                                    label: AppStrings.t(
                                      lang,
                                      'quick_upload',
                                      script: script,
                                    ),
                                    accentColor: const Color(0xFF3B82F6),
                                    isDark: isDark,
                                    glowBoost: glowBoost,
                                    onTap: () => _openQuickScan(
                                      focusCamera: false,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Right Radial Orb: Camera Scan (Emerald Green glow)
                        Positioned(
                          left: centerX + rightArcX - slotWidth / 2,
                          bottom: originBottom + rightArcY,
                          width: slotWidth,
                          child: IgnorePointer(
                            ignoring: !_scanMenuOpen,
                            child: Opacity(
                              opacity: rightFade.clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale: (0.32 + 0.68 * rightProgress)
                                    .clamp(0.2, 1.15),
                                child: Transform.rotate(
                                  angle: 0.35 *
                                      (1.0 - rightProgress.clamp(0.0, 1.0)),
                                  child: _RadialScanOrb(
                                    key: const Key('scan_quick_camera'),
                                    size: orbSize,
                                    icon: CupertinoIcons.camera,
                                    label: AppStrings.t(
                                      lang,
                                      'quick_camera',
                                      script: script,
                                    ),
                                    accentColor: const Color(0xFF10B981),
                                    isDark: isDark,
                                    glowBoost: glowBoost,
                                    onTap: () => _openQuickScan(
                                      focusCamera: true,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: bottomPad + 10,
                  child: _IphoneFloatingGlassNavBar(
                    currentIndex: widget.navigationShell.currentIndex,
                    lang: lang,
                    script: script,
                    isDark: isDark,
                    scanMenuOpen: _scanMenuOpen,
                    rolePrimary: c.rolePrimary,
                    gradientStart: c.roleGradientStart,
                    gradientEnd: c.roleGradientEnd,
                    roleGlow: c.roleGlow,
                    textSecondary: c.textSecondary,
                    onSelect: _go,
                    onScan: _toggleScanMenu,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RadialScanOrb extends StatefulWidget {
  const _RadialScanOrb({
    super.key,
    required this.size,
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.isDark,
    required this.glowBoost,
    required this.onTap,
  });

  final double size;
  final IconData icon;
  final String label;
  final Color accentColor;
  final bool isDark;
  final double glowBoost;
  final VoidCallback onTap;

  @override
  State<_RadialScanOrb> createState() => _RadialScanOrbState();
}

class _RadialScanOrbState extends State<_RadialScanOrb> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fill = widget.isDark
        ? const Color(0xE01A2234)
        : const Color(0xECFFFFFF);
    final border = widget.isDark
        ? widget.accentColor.withValues(alpha: 0.36)
        : widget.accentColor.withValues(alpha: 0.28);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withValues(
                      alpha: (widget.isDark ? 0.42 : 0.32) * widget.glowBoost,
                    ),
                    blurRadius: 24 * widget.glowBoost,
                    spreadRadius: 1,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: widget.isDark ? 0.36 : 0.12,
                    ),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: fill,
                      gradient: RadialGradient(
                        center: const Alignment(-0.25, -0.35),
                        radius: 1.05,
                        colors: [
                          widget.accentColor.withValues(
                            alpha: widget.isDark ? 0.22 : 0.12,
                          ),
                          fill,
                        ],
                      ),
                      border: Border.all(color: border, width: 1.3),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.accentColor,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.48),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IphoneFloatingGlassNavBar extends StatelessWidget {
  const _IphoneFloatingGlassNavBar({
    required this.currentIndex,
    required this.lang,
    required this.script,
    required this.isDark,
    required this.scanMenuOpen,
    required this.rolePrimary,
    required this.gradientStart,
    required this.gradientEnd,
    required this.roleGlow,
    required this.textSecondary,
    required this.onSelect,
    required this.onScan,
  });

  final int currentIndex;
  final AppLang lang;
  final UzbekScript script;
  final bool isDark;
  final bool scanMenuOpen;
  final Color rolePrimary;
  final Color gradientStart;
  final Color gradientEnd;
  final Color roleGlow;
  final Color textSecondary;
  final ValueChanged<int> onSelect;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final pillFill =
        isDark ? const Color(0xEB1A1D24) : const Color(0xEBFFFFFF);
    final pillBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.90);

    return RepaintBoundary(
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.36 : 0.11),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: pillFill,
                borderRadius: BorderRadius.circular(35),
                border: Border.all(color: pillBorder, width: 1.0),
              ),
              child: Row(
                children: [
                  _GlassNavItem(
                    icon: CupertinoIcons.house,
                    activeIcon: CupertinoIcons.house_fill,
                    label: AppStrings.t(lang, 'nav_home', script: script),
                    selected: currentIndex == 0,
                    isDark: isDark,
                    activeColor: rolePrimary,
                    inactiveColor: textSecondary,
                    onTap: () => onSelect(0),
                  ),
                  _GlassNavItem(
                    icon: CupertinoIcons.doc_text,
                    activeIcon: CupertinoIcons.doc_text_fill,
                    label: AppStrings.t(lang, 'nav_docs', script: script),
                    selected: currentIndex == 1,
                    isDark: isDark,
                    activeColor: rolePrimary,
                    inactiveColor: textSecondary,
                    onTap: () => onSelect(1),
                  ),
                  // Centered Role-Tinted Scan Orb inside the stadium pill bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        key: const Key('center_scan_fab'),
                        customBorder: const CircleBorder(),
                        onTap: onScan,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [gradientStart, gradientEnd],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: roleGlow,
                                blurRadius: scanMenuOpen ? 18 : 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: AnimatedRotation(
                            turns: scanMenuOpen ? 0.25 : 0.0,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: Icon(
                                scanMenuOpen
                                    ? CupertinoIcons.xmark
                                    : CupertinoIcons.qrcode_viewfinder,
                                key: ValueKey(scanMenuOpen),
                                color: Colors.white,
                                size: scanMenuOpen ? 22 : 25,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _GlassNavItem(
                    icon: CupertinoIcons.book,
                    activeIcon: CupertinoIcons.book_fill,
                    label: AppStrings.t(lang, 'nav_laws', script: script),
                    selected: currentIndex == 2,
                    isDark: isDark,
                    activeColor: rolePrimary,
                    inactiveColor: textSecondary,
                    onTap: () => onSelect(2),
                  ),
                  _GlassNavItem(
                    icon: CupertinoIcons.person,
                    activeIcon: CupertinoIcons.person_fill,
                    label: AppStrings.t(lang, 'nav_profile', script: script),
                    selected: currentIndex == 3,
                    isDark: isDark,
                    activeColor: rolePrimary,
                    inactiveColor: textSecondary,
                    onTap: () => onSelect(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassNavItem extends StatelessWidget {
  const _GlassNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.isDark,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final bool isDark;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? (isDark ? Colors.white : activeColor)
        : inactiveColor;
    final capsuleColor = selected
        ? (isDark
            ? Colors.white.withValues(alpha: 0.14)
            : activeColor.withValues(alpha: 0.12))
        : Colors.transparent;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 50,
              height: 30,
              decoration: BoxDecoration(
                color: capsuleColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(selected ? activeIcon : icon, size: 20, color: fg),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: fg,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullDesktopTopBar extends StatelessWidget {
  const _FullDesktopTopBar({
    required this.segment,
    required this.lang,
    required this.script,
    required this.onTogglePhone,
  });

  final AccountSegment segment;
  final AppLang lang;
  final UzbekScript script;
  final VoidCallback onTogglePhone;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final roleName = segment == AccountSegment.business
        ? AppStrings.t(lang, 'business_b2b', script: script)
        : AppStrings.t(lang, 'individual_b2c', script: script);
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: c.glassFillStrong,
        border: Border(bottom: BorderSide(color: c.glassBorder)),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.shield_lefthalf_fill,
            color: c.rolePrimary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'LexGuard AI · $roleName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
          ),
          GlassPill(
            onTap: onTogglePhone,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.device_phone_portrait,
                  size: 14,
                  color: c.rolePrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  AppStrings.t(lang, 'desktop_phone_view', script: script),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopGlassRail extends StatelessWidget {
  const _DesktopGlassRail({
    required this.currentIndex,
    required this.lang,
    required this.script,
    required this.onSelect,
    required this.onScan,
  });

  final int currentIndex;
  final AppLang lang;
  final UzbekScript script;
  final ValueChanged<int> onSelect;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    return Container(
      width: 224,
      margin: const EdgeInsets.fromLTRB(14, 14, 0, 14),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        radius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              key: const Key('desktop_scan_btn'),
              onPressed: onScan,
              icon: const Icon(CupertinoIcons.viewfinder, size: 18),
              label: Text(AppStrings.t(lang, 'scan', script: script)),
            ),
            const SizedBox(height: 18),
            _RailTile(
              icon: CupertinoIcons.house_fill,
              label: AppStrings.t(lang, 'nav_home', script: script),
              selected: currentIndex == 0,
              color: c.rolePrimary,
              textPrimary: c.textPrimary,
              onTap: () => onSelect(0),
            ),
            _RailTile(
              icon: CupertinoIcons.doc_text_fill,
              label: AppStrings.t(lang, 'nav_docs', script: script),
              selected: currentIndex == 1,
              color: c.rolePrimary,
              textPrimary: c.textPrimary,
              onTap: () => onSelect(1),
            ),
            _RailTile(
              icon: CupertinoIcons.book_fill,
              label: AppStrings.t(lang, 'nav_laws', script: script),
              selected: currentIndex == 2,
              color: c.rolePrimary,
              textPrimary: c.textPrimary,
              onTap: () => onSelect(2),
            ),
            _RailTile(
              icon: CupertinoIcons.person_fill,
              label: AppStrings.t(lang, 'nav_profile', script: script),
              selected: currentIndex == 3,
              color: c.rolePrimary,
              textPrimary: c.textPrimary,
              onTap: () => onSelect(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailTile extends StatelessWidget {
  const _RailTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.textPrimary,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final Color textPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.13) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: selected ? color : textPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? color : textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
