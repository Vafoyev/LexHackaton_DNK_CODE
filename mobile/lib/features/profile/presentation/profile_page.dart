import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.t(lang, 'profile_title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: c.brandDeepBlue,
                    child: const Icon(
                      Icons.business_center_rounded,
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${session.userName} · ${session.authProviderLabel}',
                          style: TextStyle(fontSize: 12.5, color: c.grayText),
                        ),
                      ],
                    ),
                  ),
                  SegmentedButton<AccountSegment>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: AccountSegment.business,
                        label: Text('B2B', style: TextStyle(fontSize: 11)),
                      ),
                      ButtonSegment(
                        value: AccountSegment.individual,
                        label: Text('B2C', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                    selected: {session.segment},
                    onSelectionChanged: (v) => cubit.setSegment(v.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Mock OneID / E-IMZO Auth Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Davlat identifikatsiyasi (MVPda Mock Adapter)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'OneID paroli yoki E-IMZO .pfx fayli hech qachon ilova/serverga kiritilmaydi.',
                    style: TextStyle(fontSize: 12, color: c.grayText),
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
                                content: Text(
                                  'OneID MOCK sessiyasi faollashtirildi.',
                                ),
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
          ),
          const SizedBox(height: 14),
          // 3.2 Pricing & Quota Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '3.2 Tariflar (Pilot gipoteza · Cheksiz tarif yo‘q)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
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
                    detail: 'Payme / Click orqali bir martalik tahlil (keyin)',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Security Controls (OWASP MASVS-L2)
          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: const Text(
                    'Skrinshotdan himoya (FLAG_SECURE)',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Androidda shartnomalarni skrinshot va ekran yozishdan bloklaydi',
                    style: TextStyle(fontSize: 11.5, color: c.grayText),
                  ),
                  value: session.flagSecureEnabled,
                  onChanged: cubit.setFlagSecure,
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  title: const Text(
                    'App Switcher Privacy Curtain',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Ilovadan chiqqanda oynani xiralashtirib yashiradi',
                    style: TextStyle(fontSize: 11.5, color: c.grayText),
                  ),
                  value: session.privacyCurtainEnabled,
                  onChanged: cubit.setPrivacyCurtain,
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  title: const Text(
                    'Biometrik qulf (Demo sozlama)',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  value: session.biometricLockEnabled,
                  onChanged: cubit.setBiometricLock,
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  title: const Text(
                    'Tungi rejim (Dark Mode)',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  value: session.themeMode == ThemeMode.dark,
                  onChanged: (_) => cubit.toggleThemeMode(),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text(
                    'Interfeys tili (UZ / RU / EN)',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  trailing: SegmentedButton<AppLang>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: AppLang.uz, label: Text('UZ')),
                      ButtonSegment(value: AppLang.ru, label: Text('RU')),
                      ButtonSegment(value: AppLang.en, label: Text('EN')),
                    ],
                    selected: {session.lang},
                    onSelectionChanged: (v) => cubit.setLang(v.first),
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
                    color: active ? c.brandDeepBlue : null,
                  ),
                ),
                Text(detail, style: TextStyle(fontSize: 11.5, color: c.grayText)),
              ],
            ),
          ),
          Text(
            price,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: active ? c.greenText : c.brandDeepBlue,
            ),
          ),
        ],
      ),
    );
  }
}
