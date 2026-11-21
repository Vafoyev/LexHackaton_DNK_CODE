import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../contracts/domain/entities/lex_models.dart';
import '../../session/presentation/cubit/session_cubit.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    final session = context.watch<SessionCubit>().state;
    final cubit = context.read<SessionCubit>();
    final lang = session.lang;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 114),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 12),
            child: Text(
              AppStrings.t(lang, 'profile_title'),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
                color: c.textPrimary,
              ),
            ),
          ),

          // Dual-Role Executive Identity Card + Instant Color Theme Swap
          GlassCard(
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [c.roleGradientStart, c.roleGradientEnd],
                        ),
                      ),
                      child: Icon(
                        session.segment == AccountSegment.business
                            ? CupertinoIcons.building_2_fill
                            : CupertinoIcons.person_crop_circle_fill,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.organizationName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary,
                            ),
                          ),
                          Text(
                            '${session.userName} · ${session.authProviderLabel}',
                            style: TextStyle(
                              fontSize: 12,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _RolePaletteBtn(
                        title: 'Jismoniy shaxs',
                        colorLabel: 'Sapphire #0066FF',
                        swatch: const Color(0xFF0066FF),
                        selected: session.segment == AccountSegment.individual,
                        onTap: () => cubit.setSegment(AccountSegment.individual),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RolePaletteBtn(
                        title: 'Yuridik (B2B)',
                        colorLabel: 'Emerald #047857',
                        swatch: const Color(0xFF047857),
                        selected: session.segment == AccountSegment.business,
                        onTap: () => cubit.setSegment(AccountSegment.business),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    cubit.returnToRoleSelect();
                    context.go('/role-select');
                  },
                  icon: const Icon(CupertinoIcons.arrow_2_circlepath, size: 16),
                  label: const Text('Rol tanlash ekraniga o‘tish'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Mock OneID / E-IMZO
          GlassCard(
            radius: 22,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Davlat identifikatsiyasi (MVPda Mock Adapter)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'OneID paroli yoki E-IMZO .pfx kaliti hech qachon ilova/serverga kiritilmaydi.',
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          cubit.signInMockProvider('OneID (MOCK)');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('OneID MOCK sessiyasi faollashtirildi.'),
                            ),
                          );
                        },
                        child: const Text('OneID (Mock)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          cubit.signInMockProvider('E-IMZO (MOCK)');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'E-IMZO kalitsiz MOCK sessiyasi faollashtirildi.',
                              ),
                            ),
                          );
                        },
                        child: const Text('E-IMZO (Mock)'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 3.2 Tariffs
          GlassCard(
            radius: 22,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '3.2 Tariflar (Cheksiz tarif yo‘q)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                _PlanRow(
                  title: 'Sinov (Joriy)',
                  price: '0 so‘m',
                  detail: '14 kun · kuniga 3 ta, jami 10 ta · 7 kun saqlash',
                  active: true,
                ),
                const Divider(),
                _PlanRow(
                  title: 'B2B Business',
                  price: '199 000 so‘m/oy',
                  detail: '30 tahlil/oy · qo‘shimcha 9 900 so‘m · 30 kun saqlash',
                ),
                const Divider(),
                _PlanRow(
                  title: 'B2B Pro',
                  price: '399 000 so‘m/oy',
                  detail: '80 tahlil/oy · rollar, audit · bank/e-faktura',
                ),
                const Divider(),
                _PlanRow(
                  title: 'B2C (Keyingi bosqich)',
                  price: '19 900 so‘m/hujjat',
                  detail: 'Payme / Click orqali bir martalik tahlil',
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // iOS Security Controls
          GlassCard(
            radius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                _CupertinoSettingRow(
                  title: 'Skrinshotdan himoya (FLAG_SECURE)',
                  subtitle: 'Androidda shartnomalarni skrinshotdan bloklaydi',
                  value: session.flagSecureEnabled,
                  onChanged: cubit.setFlagSecure,
                ),
                const Divider(height: 1),
                _CupertinoSettingRow(
                  title: 'App Switcher Privacy Curtain',
                  subtitle: 'Ilovadan chiqqanda oynani xiralashtirib yashiradi',
                  value: session.privacyCurtainEnabled,
                  onChanged: cubit.setPrivacyCurtain,
                ),
                const Divider(height: 1),
                _CupertinoSettingRow(
                  title: 'Biometrik qulf (Demo sozlama)',
                  subtitle: 'FaceID / Barmoq izi himoyasi',
                  value: session.biometricLockEnabled,
                  onChanged: cubit.setBiometricLock,
                ),
                const Divider(height: 1),
                _CupertinoSettingRow(
                  title: 'Tungi rejim (Dark Mode)',
                  subtitle: 'Chuqur obsidian oynali interfeys',
                  value: session.themeMode == ThemeMode.dark,
                  onChanged: (_) => cubit.toggleThemeMode(),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Interfeys tili',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      CupertinoSlidingSegmentedControl<AppLang>(
                        groupValue: session.lang,
                        children: const {
                          AppLang.uz: Text('UZ', style: TextStyle(fontSize: 12)),
                          AppLang.ru: Text('RU', style: TextStyle(fontSize: 12)),
                          AppLang.en: Text('EN', style: TextStyle(fontSize: 12)),
                        },
                        onValueChanged: (v) {
                          if (v != null) cubit.setLang(v);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            onTap: () {
              cubit.logout();
              context.go('/role-select');
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.square_arrow_left,
                  size: 18,
                  color: c.redText,
                ),
                const SizedBox(width: 8),
                Text(
                  'Chiqish / Kirish ekraniga qaytish',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: c.redText,
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

class _RolePaletteBtn extends StatelessWidget {
  const _RolePaletteBtn({
    required this.title,
    required this.colorLabel,
    required this.swatch,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String colorLabel;
  final Color swatch;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? swatch.withValues(alpha: 0.13) : c.grayBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? swatch : c.cardBorder,
            width: selected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 10, backgroundColor: swatch),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                    ),
                  ),
                  Text(
                    colorLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CupertinoSettingRow extends StatelessWidget {
  const _CupertinoSettingRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11.5, color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          CupertinoSwitch(
            activeTrackColor: c.rolePrimary,
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.title,
    required this.price,
    required this.detail,
    this.active = false,
  });

  final String title;
  final String price;
  final String detail;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.lexColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: active ? c.rolePrimaryDark : c.textPrimary,
                  ),
                ),
                Text(
                  detail,
                  style: TextStyle(fontSize: 11.5, color: c.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            price,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: active ? c.greenText : c.rolePrimary,
            ),
          ),
        ],
      ),
    );
  }
}
