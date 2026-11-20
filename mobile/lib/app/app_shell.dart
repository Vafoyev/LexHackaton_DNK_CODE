import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme/app_theme.dart';
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWideScreen = screenWidth >= 840;

    final mobileScaffold = Scaffold(
      extendBody: true,
      body: navigationShell,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.brandDeepBlue, c.brandCyan],
          ),
          border: Border.all(
            color: Theme.of(context).colorScheme.surface,
            width: 3.5,
          ),
          boxShadow: [
            BoxShadow(
              color: c.brandPrimaryBlue.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            key: const Key('center_scan_fab'),
            customBorder: const CircleBorder(),
            onTap: () => ScanUploadSheet.show(context),
            child: const Icon(
              Icons.document_scanner_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        elevation: 10,
        child: Row(
          children: [
            _NavTab(
              icon: Icons.home_rounded,
              label: AppStrings.t(lang, 'nav_home'),
              selected: navigationShell.currentIndex == 0,
              onTap: () => _go(0),
            ),
            _NavTab(
              icon: Icons.folder_copy_rounded,
              label: AppStrings.t(lang, 'nav_docs'),
              selected: navigationShell.currentIndex == 1,
              onTap: () => _go(1),
            ),
            const SizedBox(width: 64),
            _NavTab(
              icon: Icons.gavel_rounded,
              label: AppStrings.t(lang, 'nav_laws'),
              selected: navigationShell.currentIndex == 2,
              onTap: () => _go(2),
            ),
            _NavTab(
              icon: Icons.person_rounded,
              label: AppStrings.t(lang, 'nav_profile'),
              selected: navigationShell.currentIndex == 3,
              onTap: () => _go(3),
            ),
          ],
        ),
      ),
    );

    if (!isWideScreen) {
      return mobileScaffold;
    }

    // On Windows / macOS / Linux / Web wide screens:
    // Offer authentic Soliq mobile frame preview + 1-click full Desktop workspace toggle!
    if (session.phoneFrameOnDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Column(
          children: [
            _DesktopPreviewBar(
              isPhoneFrame: true,
              onToggle: () => context.read<SessionCubit>().toggleDesktopFrame(),
            ),
            Expanded(
              child: Center(
                child: Container(
                  width: 430,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(
                      color: const Color(0xFF334155),
                      width: 6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 32,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      padding: const EdgeInsets.only(top: 12),
                    ),
                    child: mobileScaffold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Full Desktop Workspace (Windows / macOS / Linux / Web)
    return Scaffold(
      body: Column(
        children: [
          _DesktopPreviewBar(
            isPhoneFrame: false,
            onToggle: () => context.read<SessionCubit>().toggleDesktopFrame(),
          ),
          Expanded(
            child: Row(
              children: [
                NavigationRail(
                  extended: screenWidth >= 1100,
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _go,
                  leading: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
                    child: FilledButton.icon(
                      key: const Key('desktop_scan_btn'),
                      onPressed: () => ScanUploadSheet.show(context),
                      icon: const Icon(Icons.document_scanner_rounded),
                      label: Text(AppStrings.t(lang, 'scan')),
                    ),
                  ),
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.home_outlined),
                      selectedIcon: const Icon(Icons.home_rounded),
                      label: Text(AppStrings.t(lang, 'nav_home')),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.folder_copy_outlined),
                      selectedIcon: const Icon(Icons.folder_copy_rounded),
                      label: Text(AppStrings.t(lang, 'nav_docs')),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.gavel_outlined),
                      selectedIcon: const Icon(Icons.gavel_rounded),
                      label: Text(AppStrings.t(lang, 'nav_laws')),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.person_outline),
                      selectedIcon: const Icon(Icons.person_rounded),
                      label: Text(AppStrings.t(lang, 'nav_profile')),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _go(int idx) {
    navigationShell.goBranch(
      idx,
      initialLocation: idx == navigationShell.currentIndex,
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final color = selected ? c.brandPrimaryBlue : c.grayText;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopPreviewBar extends StatelessWidget {
  const _DesktopPreviewBar({
    required this.isPhoneFrame,
    required this.onToggle,
  });

  final bool isPhoneFrame;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: const Color(0xFF0B1120),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.devices_rounded, color: Color(0xFF38BDF8), size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'LexGuard AI · Flutter Cross-Platform (Android / iOS / macOS / Windows / Linux / Web)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onToggle,
            icon: Icon(
              isPhoneFrame ? Icons.desktop_windows_rounded : Icons.smartphone,
              color: const Color(0xFF38BDF8),
              size: 16,
            ),
            label: Text(
              isPhoneFrame ? 'Keng ekran (Desktop)' : 'Soliq Mobil ko‘rinish',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
