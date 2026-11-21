import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/language_picker_sheet.dart';
import '../../../core/widgets/theme_reveal_scope.dart';
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
      backgroundColor: c.canvasBg,
      body: AmbientGlassBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final hPad = (w * 0.065).clamp(20.0, 32.0);
              final titleSize = (w * 0.085).clamp(30.0, 38.0);

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 8),
                        child: Row(
                          children: [
                            GlassPill(
                              onTap: () => context.go('/onboarding'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Icon(
                                CupertinoIcons.chevron_back,
                                size: 17,
                                color: c.textPrimary,
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
                                      fontSize: 13,
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
                            LexThemeTogglePill(
                              isDark: session.themeMode == ThemeMode.dark,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                AppStrings.t(
                                  lang,
                                  'role_question',
                                  script: script,
                                ),
                                style: TextStyle(
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.0,
                                  height: 1.12,
                                  color: c.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 28),
                              _CleanRoleCard(
                                key: const Key('role_card_individual'),
                                title: AppStrings.t(
                                  lang,
                                  'role_individual_title',
                                  script: script,
                                ),
                                subtitle: AppStrings.t(
                                  lang,
                                  'role_individual_sub',
                                  script: script,
                                ),
                                icon: CupertinoIcons.person_fill,
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
                              const SizedBox(height: 16),
                              _CleanRoleCard(
                                key: const Key('role_card_business'),
                                title: AppStrings.t(
                                  lang,
                                  'role_business_title',
                                  script: script,
                                ),
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
                            ],
                          ),
                        ),
                      ),
                    ],
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

class _CleanRoleCard extends StatelessWidget {
  const _CleanRoleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primaryColor,
    required this.gradientColors,
    required this.onTap,
  });

  final String title;
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      borderColor: primaryColor.withValues(alpha: 0.22),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.24),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            CupertinoIcons.chevron_forward,
            size: 20,
            color: primaryColor,
          ),
        ],
      ),
    );
  }
}
