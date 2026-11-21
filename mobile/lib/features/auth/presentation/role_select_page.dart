import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/language_picker_sheet.dart';
import '../../contracts/domain/entities/lex_models.dart';
import '../../session/presentation/cubit/session_cubit.dart';

class RoleSelectPage extends StatelessWidget {
  const RoleSelectPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final session = context.watch<SessionCubit>().state;
    final lang = session.lang;
    final script = session.uzbekScript;

    return Scaffold(
      key: const Key('role_select_screen'),
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
                          Row(
                            children: [
                              GlassPill(
                                onTap: () => context.go('/onboarding'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CupertinoIcons.chevron_back,
                                      size: 14,
                                      color: c.textPrimary,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      AppStrings.t(
                                        lang,
                                        'back',
                                        script: script,
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: c.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              GlassPill(
                                key: const Key('lang_picker_pill'),
                                onTap: () => LanguagePickerSheet.show(context),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      lang.code,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: c.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      CupertinoIcons.chevron_down,
                                      size: 12,
                                      color: c.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              GlassPill(
                                key: const Key('theme_toggle_pill'),
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
                          const SizedBox(height: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
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
                                      blurRadius: 18,
                                      offset: const Offset(0, 7),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  CupertinoIcons.shield_lefthalf_fill,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                AppStrings.t(
                                  lang,
                                  'role_question',
                                  script: script,
                                ),
                                style: TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.7,
                                  height: 1.15,
                                  color: c.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppStrings.t(lang, 'role_sub', script: script),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.4,
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _ExecutiveRoleCard(
                            key: const Key('role_card_individual'),
                            title: AppStrings.t(
                              lang,
                              'role_individual_title',
                              script: script,
                            ),
                            badgeText: 'OneID · Mock',
                            subtitle: AppStrings.t(
                              lang,
                              'role_individual_sub',
                              script: script,
                            ),
                            icon: CupertinoIcons.person_crop_circle_fill,
                            primaryColor: const Color(0xFF0066FF),
                            gradientColors: const [
                              Color(0xFF0046C7),
                              Color(0xFF0A84FF),
                            ],
                            onTap: () {
                              context
                                  .read<SessionCubit>()
                                  .selectRole(AccountSegment.individual);
                              context.go('/login');
                            },
                          ),
                          const SizedBox(height: 14),
                          _ExecutiveRoleCard(
                            key: const Key('role_card_business'),
                            title: AppStrings.t(
                              lang,
                              'role_business_title',
                              script: script,
                            ),
                            badgeText: 'E-IMZO · Mock',
                            subtitle: AppStrings.t(
                              lang,
                              'role_business_sub',
                              script: script,
                            ),
                            icon: CupertinoIcons.building_2_fill,
                            primaryColor: const Color(0xFF047857),
                            gradientColors: const [
                              Color(0xFF064E3B),
                              Color(0xFF059669),
                            ],
                            onTap: () {
                              context
                                  .read<SessionCubit>()
                                  .selectRole(AccountSegment.business);
                              context.go('/login');
                            },
                          ),
                          const SizedBox(height: 22),
                          Text(
                            AppStrings.t(
                              lang,
                              'orq_1115_banner',
                              script: script,
                            ),
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
  });

  final String title;
  final String badgeText;
  final String subtitle;
  final IconData icon;
  final Color primaryColor;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
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
                  color: primaryColor.withValues(alpha: 0.26),
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
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      color: primaryColor,
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
