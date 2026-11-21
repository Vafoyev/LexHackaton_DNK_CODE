import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/language_picker_sheet.dart';
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
        duration: const Duration(milliseconds: 300),
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
      backgroundColor: Colors.transparent,
      body: AmbientGlassBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                          padding: const EdgeInsets.all(8),
                          onTap: () =>
                              context.read<SessionCubit>().toggleThemeMode(),
                          child: Icon(
                            session.themeMode == ThemeMode.dark
                                ? CupertinoIcons.sun_max_fill
                                : CupertinoIcons.moon_fill,
                            size: 15,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              key: const Key('onboarding_skip_btn'),
                              onPressed: _finishOnboarding,
                              child: Text(
                                AppStrings.t(
                                  lang,
                                  'onboarding_skip',
                                  script: script,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: c.rolePrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (idx) =>
                            setState(() => _currentPage = idx),
                        children: [
                          _SlideContainer(
                            icon: CupertinoIcons.doc_text_search,
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
                            extra: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _MiniColorPill(
                                  AppStrings.t(lang, 'red_label', script: script),
                                  c.redText,
                                  c.redBg,
                                ),
                                _MiniColorPill(
                                  AppStrings.t(
                                    lang,
                                    'yellow_label',
                                    script: script,
                                  ),
                                  c.yellowText,
                                  c.yellowBg,
                                ),
                                _MiniColorPill(
                                  AppStrings.t(
                                    lang,
                                    'gray_label',
                                    script: script,
                                  ),
                                  c.grayText,
                                  c.grayBg,
                                ),
                                _MiniColorPill(
                                  AppStrings.t(
                                    lang,
                                    'green_label',
                                    script: script,
                                  ),
                                  c.greenText,
                                  c.greenBg,
                                ),
                              ],
                            ),
                          ),
                          _SlideContainer(
                            icon: CupertinoIcons.lock_shield_fill,
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
                            extra: GlassCard(
                              radius: 14,
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.checkmark_shield_fill,
                                    size: 18,
                                    color: c.greenText,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '31205941234567 -> [JSHSHIR_1]',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: c.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _SlideContainer(
                            icon: CupertinoIcons.doc_checkmark_fill,
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
                            extra: GlassCard(
                              radius: 14,
                              padding: const EdgeInsets.all(10),
                              child: Text(
                                AppStrings.t(
                                  lang,
                                  'orq_1115_banner',
                                  script: script,
                                ),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: c.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) {
                        final active = index == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 7,
                          width: active ? 26 : 8,
                          decoration: BoxDecoration(
                            color: active
                                ? c.rolePrimary
                                : c.textSecondary.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      key: const Key('onboarding_next_btn'),
                      onTap: _nextSlide,
                      borderRadius: BorderRadius.circular(18),
                      child: Ink(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [c.roleGradientStart, c.roleGradientEnd],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: c.roleGlow,
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              CupertinoIcons.arrow_right,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideContainer extends StatelessWidget {
  const _SlideContainer({
    required this.icon,
    required this.title,
    required this.body,
    required this.extra,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget extra;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    return Center(
      child: SingleChildScrollView(
        child: GlassCard(
          radius: 28,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [c.roleGradientStart, c.roleGradientEnd],
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.48,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              extra,
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniColorPill extends StatelessWidget {
  const _MiniColorPill(this.text, this.fg, this.bg);

  final String text;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
