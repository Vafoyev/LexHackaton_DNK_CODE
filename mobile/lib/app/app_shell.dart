import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/app_strings.dart';
import '../core/l10n/uzbek_alphabet.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/glass_surface.dart';
import '../features/contracts/domain/entities/lex_models.dart';
import '../features/scanner_upload/presentation/scan_upload_sheet.dart';
import '../features/session/presentation/cubit/session_cubit.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  bool _scanMenuOpen = false;
  late final AnimationController _scanAnim;

  @override
  void initState() {
    super.initState();
    _scanAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 190),
    );
  }

  @override
  void dispose() {
    _scanAnim.dispose();
    super.dispose();
  }

  void _toggleScanMenu() {
    setState(() => _scanMenuOpen = !_scanMenuOpen);
    if (_scanMenuOpen) {
      _scanAnim.forward();
    } else {
      _scanAnim.reverse();
    }
  }

  void _closeScanMenu() {
    if (!_scanMenuOpen) return;
    setState(() => _scanMenuOpen = false);
    _scanAnim.reverse();
  }

  void _go(int idx) {
    _closeScanMenu();
    widget.navigationShell.goBranch(
      idx,
      initialLocation: idx == widget.navigationShell.currentIndex,
    );
  }

  void _openQuickScan({required bool focusCamera}) {
    _closeScanMenu();
    ScanUploadSheet.show(context, focusCamera: focusCamera);
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
                  animation: _scanAnim,
                  builder: (context, _) {
                    if (!_scanMenuOpen && _scanAnim.value == 0.0) {
                      return const SizedBox.shrink();
                    }

                    final scrimOpacity = CurvedAnimation(
                      parent: _scanAnim,
                      curve: Curves.easeOut,
                    );

                    final uploadCurve = CurvedAnimation(
                      parent: _scanAnim,
                      curve: const Interval(0.0, 0.84, curve: Curves.easeOutCubic),
                    );
                    final uploadBack = CurvedAnimation(
                      parent: _scanAnim,
                      curve: const Interval(0.0, 0.84, curve: Curves.easeOutBack),
                    );

                    final cameraCurve = CurvedAnimation(
                      parent: _scanAnim,
                      curve: const Interval(0.10, 1.0, curve: Curves.easeOutCubic),
                    );
                    final cameraBack = CurvedAnimation(
                      parent: _scanAnim,
                      curve: const Interval(0.10, 1.0, curve: Curves.easeOutBack),
                    );

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        IgnorePointer(
                          ignoring: !_scanMenuOpen,
                          child: GestureDetector(
                            key: const Key('scan_menu_scrim'),
                            behavior: HitTestBehavior.opaque,
                            onTap: _closeScanMenu,
                            child: FadeTransition(
                              opacity: scrimOpacity,
                              child: ColoredBox(
                                color: Colors.black.withValues(alpha: 0.24),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: bottomPad + 94,
                          child: IgnorePointer(
                            ignoring: !_scanMenuOpen,
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 340),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: FadeTransition(
                                        opacity: uploadCurve,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(0, 0.35),
                                            end: Offset.zero,
                                          ).animate(uploadBack),
                                          child: ScaleTransition(
                                            scale: Tween<double>(
                                              begin: 0.85,
                                              end: 1.0,
                                            ).animate(uploadBack),
                                            child: _ScanQuickActionCard(
                                              key: const Key('scan_quick_upload'),
                                              icon: CupertinoIcons.arrow_up_doc_fill,
                                              title: AppStrings.t(
                                                lang,
                                                'quick_upload',
                                                script: script,
                                              ),
                                              subtitle: AppStrings.t(
                                                lang,
                                                'quick_upload_sub',
                                                script: script,
                                              ),
                                              onTap: () => _openQuickScan(
                                                focusCamera: false,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: FadeTransition(
                                        opacity: cameraCurve,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(0, 0.35),
                                            end: Offset.zero,
                                          ).animate(cameraBack),
                                          child: ScaleTransition(
                                            scale: Tween<double>(
                                              begin: 0.85,
                                              end: 1.0,
                                            ).animate(cameraBack),
                                            child: _ScanQuickActionCard(
                                              key: const Key('scan_quick_camera'),
                                              icon: CupertinoIcons.camera_viewfinder,
                                              title: AppStrings.t(
                                                lang,
                                                'quick_camera',
                                                script: script,
                                              ),
                                              subtitle: AppStrings.t(
                                                lang,
                                                'quick_camera_sub',
                                                script: script,
                                              ),
                                              onTap: () => _openQuickScan(
                                                focusCamera: true,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
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

class _ScanQuickActionCard extends StatelessWidget {
  const _ScanQuickActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    return GlassCard(
      radius: 22,
      blurSigma: 26,
      tintColor: c.glassFillStrong,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.roleGradientStart, c.roleGradientEnd],
              ),
              boxShadow: [
                BoxShadow(
                  color: c.roleGlow,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: c.textSecondary,
            ),
          ),
        ],
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
