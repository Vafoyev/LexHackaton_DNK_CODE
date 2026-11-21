import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/uzbek_alphabet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/language_picker_sheet.dart';
import '../../../core/widgets/theme_reveal_scope.dart';
import '../../contracts/domain/entities/lex_models.dart';
import '../../session/presentation/cubit/session_cubit.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _inputCtrl = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  void _submitForm(AccountSegment segment, AppLang lang, UzbekScript script) {
    final value = _inputCtrl.text.trim();
    if (value.isEmpty) {
      setState(() {
        _errorText = AppStrings.t(lang, 'login_field_required', script: script);
      });
      return;
    }
    setState(() => _errorText = null);

    final isBusiness = segment == AccountSegment.business;
    context.read<SessionCubit>().completeLogin(
          providerLabel: isBusiness ? 'B2B' : 'Telefon',
          organizationName: isBusiness ? value : null,
          userName: isBusiness ? null : value,
        );
    context.go('/home');
  }

  void _signInGov(AccountSegment segment) {
    final isBusiness = segment == AccountSegment.business;
    context.read<SessionCubit>().completeLogin(
          providerLabel: isBusiness ? 'E-IMZO' : 'OneID',
          organizationName: isBusiness ? 'DNK Tech MChJ' : null,
        );
    context.go('/home');
  }

  void _enterDemo(AppLang lang, UzbekScript script) {
    context.read<SessionCubit>().completeLogin(
          providerLabel: AppStrings.t(lang, 'trial_badge', script: script),
        );
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final session = context.watch<SessionCubit>().state;
    final lang = session.lang;
    final script = session.uzbekScript;
    final isBusiness = session.segment == AccountSegment.business;

    return Scaffold(
      key: const Key('login_screen'),
      backgroundColor: c.canvasBg,
      body: AmbientGlassBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final hPad = (w * 0.065).clamp(20.0, 32.0);
              final titleSize = (w * 0.088).clamp(30.0, 38.0);

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
                              key: const Key('login_back_role_btn'),
                              onTap: () => context.go('/role-select'),
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
                            const SizedBox(width: 8),
                            GlassPill(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: c.rolePrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isBusiness
                                        ? AppStrings.t(
                                            lang,
                                            'business_b2b',
                                            script: script,
                                          )
                                        : AppStrings.t(
                                            lang,
                                            'individual_b2c',
                                            script: script,
                                          ),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
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
                                isBusiness
                                    ? AppStrings.t(
                                        lang,
                                        'login_title_business',
                                        script: script,
                                      )
                                    : AppStrings.t(
                                        lang,
                                        'login_title_individual',
                                        script: script,
                                      ),
                                style: TextStyle(
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.0,
                                  height: 1.1,
                                  color: c.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 28),
                              TextField(
                                controller: _inputCtrl,
                                keyboardType: isBusiness
                                    ? TextInputType.text
                                    : TextInputType.phone,
                                textInputAction: TextInputAction.done,
                                onChanged: (_) {
                                  if (_errorText != null) {
                                    setState(() => _errorText = null);
                                  }
                                },
                                onSubmitted: (_) => _submitForm(
                                  session.segment,
                                  lang,
                                  script,
                                ),
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  hintText: isBusiness
                                      ? AppStrings.t(
                                          lang,
                                          'login_hint_org',
                                          script: script,
                                        )
                                      : AppStrings.t(
                                          lang,
                                          'login_hint_contact',
                                          script: script,
                                        ),
                                  errorText: _errorText,
                                  hintStyle: TextStyle(
                                    color: c.textSecondary,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  prefixIcon: Icon(
                                    isBusiness
                                        ? CupertinoIcons.building_2_fill
                                        : CupertinoIcons.phone_fill,
                                    size: 19,
                                    color: c.textSecondary,
                                  ),
                                  filled: true,
                                  fillColor: c.glassFillStrong,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 18,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide:
                                        BorderSide(color: c.glassBorder),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide:
                                        BorderSide(color: c.glassBorder),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide(
                                      color: c.rolePrimary,
                                      width: 1.6,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
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
                                        color: c.rolePrimary
                                            .withValues(alpha: 0.28),
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
                                      key: const Key('login_submit_btn'),
                                      onTap: () => _submitForm(
                                        session.segment,
                                        lang,
                                        script,
                                      ),
                                      child: Center(
                                        child: Text(
                                          AppStrings.t(
                                            lang,
                                            'login_submit',
                                            script: script,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color:
                                          c.textSecondary.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    child: Text(
                                      AppStrings.t(
                                        lang,
                                        'or_divider',
                                        script: script,
                                      ),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: c.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color:
                                          c.textSecondary.withValues(alpha: 0.2),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              SizedBox(
                                height: 56,
                                child: OutlinedButton.icon(
                                  key: const Key('login_primary_auth_btn'),
                                  onPressed: () => _signInGov(session.segment),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: c.glassFillStrong,
                                    foregroundColor: c.textPrimary,
                                    side: BorderSide(
                                      color:
                                          c.rolePrimary.withValues(alpha: 0.35),
                                      width: 1.2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  icon: Icon(
                                    isBusiness
                                        ? CupertinoIcons.signature
                                        : CupertinoIcons.person_badge_plus_fill,
                                    color: c.rolePrimary,
                                    size: 20,
                                  ),
                                  label: Text(
                                    isBusiness
                                        ? AppStrings.t(
                                            lang,
                                            'login_eimzo_btn',
                                            script: script,
                                          )
                                        : AppStrings.t(
                                            lang,
                                            'login_oneid_btn',
                                            script: script,
                                          ),
                                    style: TextStyle(
                                      color: c.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Center(
                                child: TextButton(
                                  key: const Key('login_demo_btn'),
                                  onPressed: () => _enterDemo(lang, script),
                                  child: Text(
                                    AppStrings.t(
                                      lang,
                                      'login_demo',
                                      script: script,
                                    ),
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: c.rolePrimary,
                                    ),
                                  ),
                                ),
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
