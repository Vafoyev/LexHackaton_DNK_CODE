import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/uzbek_alphabet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/language_picker_sheet.dart';
import '../../contracts/domain/entities/lex_models.dart';
import '../../session/presentation/cubit/session_cubit.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _primaryCtrl = TextEditingController();
  final TextEditingController _secondaryCtrl = TextEditingController();
  int _selectedOrgIdx = 0;

  static const _demoOrgs = [
    ('DNK Tech MChJ', 'STIR 301234567'),
    ('Aloqa Servis YaTT', 'STIR 409876543'),
  ];

  @override
  void dispose() {
    _primaryCtrl.dispose();
    _secondaryCtrl.dispose();
    super.dispose();
  }

  void _completePrimaryGovAuth(AccountSegment segment) {
    final isBusiness = segment == AccountSegment.business;
    final orgName = isBusiness ? _demoOrgs[_selectedOrgIdx].$1 : null;
    context.read<SessionCubit>().completeLogin(
          providerLabel:
              isBusiness ? 'E-IMZO (Mock · B2B)' : 'OneID (Mock · Jismoniy)',
          organizationName: orgName,
        );
    context.go('/home');
  }

  void _completeFormLogin(AccountSegment segment) {
    final isBusiness = segment == AccountSegment.business;
    final enteredOrg = _primaryCtrl.text.trim();
    final enteredUser = !isBusiness && _primaryCtrl.text.trim().isNotEmpty
        ? _primaryCtrl.text.trim()
        : null;
    context.read<SessionCubit>().completeLogin(
          providerLabel: isBusiness ? 'B2B Demo' : 'Demo',
          organizationName:
              isBusiness && enteredOrg.isNotEmpty ? enteredOrg : null,
          userName: enteredUser,
        );
    context.go('/home');
  }

  void _enterDemoTrial(AccountSegment segment, AppLang lang, UzbekScript script) {
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
      backgroundColor: Colors.transparent,
      body: AmbientGlassBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        GlassPill(
                          key: const Key('login_back_role_btn'),
                          onTap: () => context.go('/role-select'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.chevron_back,
                                size: 15,
                                color: c.textPrimary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                AppStrings.t(lang, 'role_label', script: script),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: c.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: GlassPill(
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
                                Flexible(
                                  child: Text(
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
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
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: c.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                CupertinoIcons.chevron_down,
                                size: 11,
                                color: c.textSecondary,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        GlassPill(
                          key: const Key('theme_toggle_pill'),
                          onTap: () =>
                              context.read<SessionCubit>().toggleThemeMode(),
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            session.themeMode == ThemeMode.dark
                                ? CupertinoIcons.sun_max_fill
                                : CupertinoIcons.moon_fill,
                            size: 15,
                            color: c.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
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
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isBusiness
                          ? AppStrings.t(
                              lang,
                              'login_sub_business',
                              script: script,
                            )
                          : AppStrings.t(
                              lang,
                              'login_sub_individual',
                              script: script,
                            ),
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    GlassCard(
                      radius: 26,
                      padding: const EdgeInsets.all(18),
                      borderColor: c.rolePrimary.withValues(alpha: 0.3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: LinearGradient(
                                    colors: [
                                      c.roleGradientStart,
                                      c.roleGradientEnd,
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  isBusiness
                                      ? CupertinoIcons.signature
                                      : CupertinoIcons.person_badge_plus_fill,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  isBusiness
                                      ? AppStrings.t(
                                          lang,
                                          'login_eimzo_title',
                                          script: script,
                                        )
                                      : AppStrings.t(
                                          lang,
                                          'login_oneid_title',
                                          script: script,
                                        ),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: c.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isBusiness) ...[
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: List.generate(_demoOrgs.length, (i) {
                                final org = _demoOrgs[i];
                                final selected = _selectedOrgIdx == i;
                                final orgLabel = AppStrings.adaptUz(
                                  '${org.$1} · ${org.$2}',
                                  lang,
                                  script,
                                );
                                return GlassPill(
                                  onTap: () =>
                                      setState(() => _selectedOrgIdx = i),
                                  tintColor:
                                      selected ? c.rolePrimary : c.grayBg,
                                  borderColor:
                                      selected ? c.rolePrimary : c.glassBorder,
                                  child: Text(
                                    orgLabel,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: selected
                                          ? Colors.white
                                          : c.textPrimary,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Text(
                            isBusiness
                                ? AppStrings.t(
                                    lang,
                                    'login_gov_note_business',
                                    script: script,
                                  )
                                : AppStrings.t(
                                    lang,
                                    'login_gov_note_individual',
                                    script: script,
                                  ),
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              color: c.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          InkWell(
                            key: const Key('login_primary_auth_btn'),
                            onTap: () =>
                                _completePrimaryGovAuth(session.segment),
                            borderRadius: BorderRadius.circular(16),
                            child: Ink(
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    c.roleGradientStart,
                                    c.roleGradientEnd,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: c.roleGlow,
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    GlassCard(
                      radius: 24,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            isBusiness
                                ? AppStrings.t(
                                    lang,
                                    'login_alt_business',
                                    script: script,
                                  )
                                : AppStrings.t(
                                    lang,
                                    'login_alt_individual',
                                    script: script,
                                  ),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _primaryCtrl,
                            style: TextStyle(color: c.textPrimary, fontSize: 14),
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
                              hintStyle: TextStyle(
                                color: c.textSecondary,
                                fontSize: 13,
                              ),
                              filled: true,
                              fillColor: c.grayBg,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: c.glassBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: c.glassBorder),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _secondaryCtrl,
                            style: TextStyle(color: c.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: isBusiness
                                  ? AppStrings.t(
                                      lang,
                                      'login_hint_email',
                                      script: script,
                                    )
                                  : AppStrings.t(
                                      lang,
                                      'login_hint_name',
                                      script: script,
                                    ),
                              hintStyle: TextStyle(
                                color: c.textSecondary,
                                fontSize: 13,
                              ),
                              filled: true,
                              fillColor: c.grayBg,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: c.glassBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: c.glassBorder),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            key: const Key('login_submit_btn'),
                            onPressed: () =>
                                _completeFormLogin(session.segment),
                            child: Text(
                              AppStrings.t(
                                lang,
                                'login_submit',
                                script: script,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            key: const Key('login_demo_btn'),
                            onPressed: () =>
                                _enterDemoTrial(session.segment, lang, script),
                            child: Text(
                              AppStrings.t(lang, 'login_demo', script: script),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.t(lang, 'orq_1115_banner', script: script),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: c.textSecondary),
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
