import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/glass_surface.dart';
import '../features/contracts/domain/entities/lex_models.dart';
import '../features/scanner_upload/presentation/scan_upload_sheet.dart';
import '../features/session/presentation/cubit/session_cubit.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final session = context.watch<SessionCubit>().state;
    final lang = session.lang;

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
                    onTogglePhone: () =>
                        context.read<SessionCubit>().toggleDesktopFrame(),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        _DesktopGlassRail(
                          currentIndex: navigationShell.currentIndex,
                          lang: lang,
                          onSelect: _go,
                          onScan: () => ScanUploadSheet.show(context),
                        ),
                        Expanded(child: navigationShell),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Authentic iPhone Liquid Glass Shell: single floating glass dock!
        return AmbientGlassBackdrop(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              fit: StackFit.expand,
              children: [
                navigationShell,
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: MediaQuery.paddingOf(context).bottom + 10,
                  child: _IphoneFloatingGlassNavBar(
                    currentIndex: navigationShell.currentIndex,
                    lang: lang,
                    rolePrimary: c.rolePrimary,
                    gradientStart: c.roleGradientStart,
                    gradientEnd: c.roleGradientEnd,
                    roleGlow: c.roleGlow,
                    glassFill: c.glassFillStrong,
                    glassBorder: c.glassBorder,
                    textSecondary: c.textSecondary,
                    onSelect: _go,
                    onScan: () => ScanUploadSheet.show(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _go(int idx) {
    navigationShell.goBranch(
      idx,
      initialLocation: idx == navigationShell.currentIndex,
    );
  }
}

class _IphoneFloatingGlassNavBar extends StatelessWidget {
  const _IphoneFloatingGlassNavBar({
    required this.currentIndex,
    required this.lang,
    required this.rolePrimary,
    required this.gradientStart,
    required this.gradientEnd,
    required this.roleGlow,
    required this.glassFill,
    required this.glassBorder,
    required this.textSecondary,
    required this.onSelect,
    required this.onScan,
  });

  final int currentIndex;
  final AppLang lang;
  final Color rolePrimary;
  final Color gradientStart;
  final Color gradientEnd;
  final Color roleGlow;
  final Color glassFill;
  final Color glassBorder;
  final Color textSecondary;
  final ValueChanged<int> onSelect;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: glassFill,
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: glassBorder, width: 1.1),
              ),
              child: Row(
                children: [
                  _GlassNavItem(
                    icon: CupertinoIcons.house,
                    activeIcon: CupertinoIcons.house_fill,
                    label: AppStrings.t(lang, 'nav_home'),
                    selected: currentIndex == 0,
                    activeColor: rolePrimary,
                    inactiveColor: textSecondary,
                    onTap: () => onSelect(0),
                  ),
                  _GlassNavItem(
                    icon: CupertinoIcons.doc_text,
                    activeIcon: CupertinoIcons.doc_text_fill,
                    label: AppStrings.t(lang, 'nav_docs'),
                    selected: currentIndex == 1,
                    activeColor: rolePrimary,
                    inactiveColor: textSecondary,
                    onTap: () => onSelect(1),
                  ),
                  // Integrated Liquid Glass Scan Orb inside the iPhone pill dock
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
                          duration: const Duration(milliseconds: 280),
                          width: 48,
                          height: 48,
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
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            CupertinoIcons.viewfinder,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _GlassNavItem(
                    icon: CupertinoIcons.book,
                    activeIcon: CupertinoIcons.book_fill,
                    label: AppStrings.t(lang, 'nav_laws'),
                    selected: currentIndex == 2,
                    activeColor: rolePrimary,
                    inactiveColor: textSecondary,
                    onTap: () => onSelect(2),
                  ),
                  _GlassNavItem(
                    icon: CupertinoIcons.person,
                    activeIcon: CupertinoIcons.person_fill,
                    label: AppStrings.t(lang, 'nav_profile'),
                    selected: currentIndex == 3,
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
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? activeColor : inactiveColor;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          decoration: BoxDecoration(
            color: selected
                ? activeColor.withValues(alpha: 0.13)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? activeIcon : icon, size: 20, color: fg),
              const SizedBox(height: 2),
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
      ),
    );
  }
}

class _FullDesktopTopBar extends StatelessWidget {
  const _FullDesktopTopBar({
    required this.segment,
    required this.onTogglePhone,
  });

  final AccountSegment segment;
  final VoidCallback onTogglePhone;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final roleName = segment == AccountSegment.business
        ? 'Yuridik shaxs · Emerald'
        : 'Jismoniy shaxs · Sapphire';
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
              'LexGuard AI · Desktop Workspace ($roleName)',
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
                  'iPhone ko‘rinish',
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
    required this.onSelect,
    required this.onScan,
  });

  final int currentIndex;
  final AppLang lang;
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
              label: Text(AppStrings.t(lang, 'scan')),
            ),
            const SizedBox(height: 18),
            _RailTile(
              icon: CupertinoIcons.house_fill,
              label: AppStrings.t(lang, 'nav_home'),
              selected: currentIndex == 0,
              color: c.rolePrimary,
              textPrimary: c.textPrimary,
              onTap: () => onSelect(0),
            ),
            _RailTile(
              icon: CupertinoIcons.doc_text_fill,
              label: AppStrings.t(lang, 'nav_docs'),
              selected: currentIndex == 1,
              color: c.rolePrimary,
              textPrimary: c.textPrimary,
              onTap: () => onSelect(1),
            ),
            _RailTile(
              icon: CupertinoIcons.book_fill,
              label: AppStrings.t(lang, 'nav_laws'),
              selected: currentIndex == 2,
              color: c.rolePrimary,
              textPrimary: c.textPrimary,
              onTap: () => onSelect(2),
            ),
            _RailTile(
              icon: CupertinoIcons.person_fill,
              label: AppStrings.t(lang, 'nav_profile'),
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
