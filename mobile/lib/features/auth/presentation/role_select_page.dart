import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../contracts/domain/entities/lex_models.dart';
import '../../session/presentation/cubit/session_cubit.dart';

class RoleSelectPage extends StatelessWidget {
  const RoleSelectPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final session = context.watch<SessionCubit>().state;
    final lang = session.lang;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientGlassBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight - 38),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top minimal iOS bar (Lang + Theme pills)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              GlassPill(
                                onTap: () =>
                                    context.read<SessionCubit>().cycleLang(),
                                child: Text(
                                  lang.code,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: c.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GlassPill(
                                onTap: () => context
                                    .read<SessionCubit>()
                                    .toggleThemeMode(),
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  session.themeMode == ThemeMode.dark
                                      ? CupertinoIcons.sun_max_fill
                                      : CupertinoIcons.moon_fill,
                                  size: 16,
                                  color: c.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          // Minimal Apple Emblem + Large Title
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      c.roleGradientStart,
                                      c.roleGradientEnd,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: c.roleGlow,
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  CupertinoIcons.shield_lefthalf_fill,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'LexGuard AI',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.9,
                                  color: c.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Shartnomani imzolashdan oldin tekshiring. O‘zingizga mos kirish rolini tanlang — har bir rol o‘z muhiti va rang tizimida ishlaydi.',
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 26),
                          // Role 1: Jismoniy shaxs — Sapphire Ice (#0066FF)
                          _ExecutiveRoleCard(
                            key: const Key('role_card_individual'),
                            title: 'Jismoniy shaxs',
                            badgeText: 'SAPPHIRE · ONEID (MOCK)',
                            subtitle:
                                'Shaxsiy shartnomalar, uy/avto oldi-sotdi notarial tekshiruvi (R6), 14 kun sinov rejimi.',
                            icon: CupertinoIcons.person_crop_circle_fill,
                            primaryColor: const Color(0xFF0066FF),
                            gradientColors: const [
                              Color(0xFF0046C7),
                              Color(0xFF0A84FF),
                            ],
                            onTap: () {
                              context
                                  .read<SessionCubit>()
                                  .enterRole(AccountSegment.individual);
                              context.go('/home');
                            },
                          ),
                          const SizedBox(height: 16),
                          // Role 2: Yuridik shaxs (B2B) — Deep Executive Emerald (#047857)
                          _ExecutiveRoleCard(
                            key: const Key('role_card_business'),
                            title: 'Yuridik shaxs (B2B)',
                            badgeText: 'EMERALD · E-IMZO (MOCK)',
                            subtitle:
                                'Xizmat ko‘rsatish va yetkazib berish shartnomalari, pretenziya bayonnomasi va jamoaviy tarix.',
                            icon: CupertinoIcons.building_2_fill,
                            primaryColor: const Color(0xFF047857),
                            gradientColors: const [
                              Color(0xFF064E3B),
                              Color(0xFF059669),
                            ],
                            accentTagColor: const Color(0xFFD4AF37),
                            onTap: () {
                              context
                                  .read<SessionCubit>()
                                  .enterRole(AccountSegment.business);
                              context.go('/home');
                            },
                          ),
                          const SizedBox(height: 24),
                          Text(
                            AppStrings.t(lang, 'orq_1115_banner'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ExecutiveRoleCard extends StatelessWidget {
  const _ExecutiveRoleCard({
    super.key,
    required this.title,
    required this.badgeText,
    required this.subtitle,
    required this.icon,
    required this.primaryColor,
    required this.gradientColors,
    required this.onTap,
    this.accentTagColor,
  });

  final String title;
  final String badgeText;
  final String subtitle;
  final IconData icon;
  final Color primaryColor;
  final List<Color> gradientColors;
  final Color? accentTagColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final tagColor = accentTagColor ?? primaryColor;
    return GlassCard(
      onTap: onTap,
      radius: 26,
      padding: const EdgeInsets.all(18),
      borderColor: primaryColor.withValues(alpha: 0.25),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.30),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tagColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: accentTagColor != null
                          ? const Color(0xFF92400E)
                          : primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Icon(
              CupertinoIcons.chevron_right_circle_fill,
              size: 24,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
