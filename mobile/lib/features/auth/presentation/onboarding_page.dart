import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/language_picker_sheet.dart';
import '../../../core/widgets/theme_reveal_scope.dart';
import '../../session/presentation/cubit/session_cubit.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finishOnboarding() {
    context.read<SessionCubit>().completeOnboarding();
    context.go('/role-select');
  }

  void _nextSlide() {
    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final session = context.watch<SessionCubit>().state;
    final lang = session.lang;
    final script = session.uzbekScript;

    return Scaffold(
      key: const Key('onboarding_screen'),
      backgroundColor: c.canvasBg,
      body: AmbientGlassBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              final hPad = (w * 0.065).clamp(20.0, 32.0);
              final iconSize = (h * 0.12).clamp(76.0, 108.0);
              final titleSize = (w * 0.082).clamp(28.0, 36.0);
              final bodySize = (w * 0.044).clamp(16.0, 19.0);

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 22),
                    child: Column(
                      children: [
                        Row(
                          children: [
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
                            const Spacer(),
                            TextButton(
                              key: const Key('onboarding_skip_btn'),
                              onPressed: _finishOnboarding,
                              child: Text(
                                AppStrings.t(
                                  lang,
                                  'onboarding_skip',
                                  script: script,
                                ),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: c.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Expanded(
                          child: PageView(
                            controller: _pageController,
                            onPageChanged: (idx) =>
                                setState(() => _currentPage = idx),
                            children: [
                              _MinimalSlide(
                                icon: CupertinoIcons.doc_text_search,
                                iconSize: iconSize,
                                title: AppStrings.t(
                                  lang,
                                  'onb_1_title',
                                  script: script,
                                ),
                                body: AppStrings.t(
                                  lang,
                                  'onb_1_body',
                                  script: script,
                                ),
                                titleSize: titleSize,
                                bodySize: bodySize,
                                accentWidget: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _ColorDot(c.redText),
                                    const SizedBox(width: 10),
                                    _ColorDot(c.yellowText),
                                    const SizedBox(width: 10),
                                    _ColorDot(c.greenText),
                                  ],
                                ),
                              ),
                              _MinimalSlide(
                                icon: CupertinoIcons.lock_shield_fill,
                                iconSize: iconSize,
                                title: AppStrings.t(
                                  lang,
                                  'onb_2_title',
                                  script: script,
                                ),
                                body: AppStrings.t(
                                  lang,
                                  'onb_2_body',
                                  script: script,
                                ),
                                titleSize: titleSize,
                                bodySize: bodySize,
                              ),
                              _MinimalSlide(
                                icon: CupertinoIcons.doc_checkmark_fill,
                                iconSize: iconSize,
                                title: AppStrings.t(
                                  lang,
                                  'onb_3_title',
                                  script: script,
                                ),
                                body: AppStrings.t(
                                  lang,
                                  'onb_3_body',
                                  script: script,
                                ),
                                titleSize: titleSize,
                                bodySize: bodySize,
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (index) {
                            final active = index == _currentPage;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 7,
                              width: active ? 28 : 7,
                              decoration: BoxDecoration(
                                color: active
                                    ? c.rolePrimary
                                    : c.textSecondary.withValues(alpha: 0.24),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  c.roleGradientStart,
                                  c.roleGradientEnd,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: c.rolePrimary.withValues(alpha: 0.28),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                key: const Key('onboarding_next_btn'),
                                onTap: _nextSlide,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _currentPage == 2
                                          ? AppStrings.t(
                                              lang,
                                              'onboarding_start',
                                              script: script,
                                            )
                                          : AppStrings.t(
                                              lang,
                                              'onboarding_next',
                                              script: script,
                                            ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      CupertinoIcons.arrow_right,
                                      color: Colors.white,
                                      size: 19,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

class _MinimalSlide extends StatelessWidget {
  const _MinimalSlide({
    required this.icon,
    required this.iconSize,
    required this.title,
    required this.body,
    required this.titleSize,
    required this.bodySize,
    this.accentWidget,
  });

  final IconData icon;
  final double iconSize;
  final String title;
  final String body;
  final double titleSize;
  final double bodySize;
  final Widget? accentWidget;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(iconSize * 0.28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c.roleGradientStart, c.roleGradientEnd],
                ),
                boxShadow: [
                  BoxShadow(
                    color: c.rolePrimary.withValues(alpha: 0.24),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: iconSize * 0.48),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.9,
                height: 1.12,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: bodySize,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  color: c.textSecondary,
                ),
              ),
            ),
            if (accentWidget != null) ...[
              const SizedBox(height: 22),
              accentWidget!,
            ],
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
